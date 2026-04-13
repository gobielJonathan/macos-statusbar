import Combine
import Darwin
import Foundation
import IOKit

struct SystemSnapshot {
    let timestamp: Date
    let cpuUsage: CPUUsageSnapshot?
    let memory: MemorySnapshot?
    let network: NetworkThroughput?
    let gpuUsage: Double?

    static let placeholder = SystemSnapshot(
        timestamp: .now,
        cpuUsage: nil,
        memory: nil,
        network: nil,
        gpuUsage: nil
    )
}

struct CPUUsageSnapshot {
    let userRatio: Double
    let systemRatio: Double
    let idleRatio: Double

    var totalRatio: Double {
        min(max(userRatio + systemRatio, 0), 1)
    }
}

struct MemorySnapshot {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    let totalBytes: UInt64

    var usedBytes: UInt64 {
        appBytes + wiredBytes + compressedBytes
    }

    var usageRatio: Double? {
        guard totalBytes > 0 else {
            return nil
        }

        return Double(usedBytes) / Double(totalBytes)
    }
}

struct NetworkThroughput {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder

    private let cpuSampler = CPUSampler()
    private let memorySampler = MemorySampler()
    private let networkSampler = NetworkSampler()
    private let gpuSampler = GPUSampler()
    private var timer: Timer?

    init() {
        refresh()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let now = Date()

        snapshot = SystemSnapshot(
            timestamp: now,
            cpuUsage: cpuSampler.usage(),
            memory: memorySampler.sample(),
            network: networkSampler.throughput(at: now),
            gpuUsage: gpuSampler.usage()
        )
    }
}

private final class CPUSampler {
    private var previousLoadInfo: host_cpu_load_info_data_t?

    func usage() -> CPUUsageSnapshot? {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        defer {
            previousLoadInfo = loadInfo
        }

        guard let previousLoadInfo else {
            return nil
        }

        let user = Double(loadInfo.cpu_ticks.0 - previousLoadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1 - previousLoadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2 - previousLoadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3 - previousLoadInfo.cpu_ticks.3)
        let totalTicks = user + system + idle + nice

        guard totalTicks > 0 else {
            return nil
        }

        let userRatio = min(max((user + nice) / totalTicks, 0), 1)
        let systemRatio = min(max(system / totalTicks, 0), 1)
        let idleRatio = min(max(idle / totalTicks, 0), 1)

        return CPUUsageSnapshot(
            userRatio: userRatio,
            systemRatio: systemRatio,
            idleRatio: idleRatio
        )
    }
}

private struct MemorySampler {
    func sample() -> MemorySnapshot? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        let purgeablePages = UInt64(statistics.purgeable_count)
        let internalPages = UInt64(statistics.internal_page_count)
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let wiredPages = UInt64(statistics.wire_count)
        let compressedPages = UInt64(statistics.compressor_page_count)
        let cachedPages = UInt64(statistics.external_page_count) + purgeablePages

        return MemorySnapshot(
            appBytes: appPages * UInt64(pageSize),
            wiredBytes: wiredPages * UInt64(pageSize),
            compressedBytes: compressedPages * UInt64(pageSize),
            cachedBytes: cachedPages * UInt64(pageSize),
            totalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }
}

private final class NetworkSampler {
    private struct Counters {
        let receivedBytes: UInt64
        let sentBytes: UInt64
    }

    private var previousSample: (timestamp: Date, counters: Counters)?

    func throughput(at date: Date) -> NetworkThroughput? {
        guard let currentCounters = counters() else {
            return nil
        }

        defer {
            previousSample = (timestamp: date, counters: currentCounters)
        }

        guard let previousSample else {
            return nil
        }

        let interval = date.timeIntervalSince(previousSample.timestamp)
        guard interval > 0.25 else {
            return nil
        }

        let download = Double(currentCounters.receivedBytes &- previousSample.counters.receivedBytes) / interval
        let upload = Double(currentCounters.sentBytes &- previousSample.counters.sentBytes) / interval

        return NetworkThroughput(
            downloadBytesPerSecond: max(download, 0),
            uploadBytesPerSecond: max(upload, 0)
        )
    }

    private func counters() -> Counters? {
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return nil
        }

        defer {
            freeifaddrs(interfacePointer)
        }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let currentInterface = cursor {
            let interface = currentInterface.pointee
            cursor = interface.ifa_next

            guard interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else {
                continue
            }

            let interfaceName = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            guard !interfaceName.isEmpty, (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0 else {
                continue
            }

            guard let interfaceData = interface.ifa_data?.assumingMemoryBound(to: if_data.self) else {
                continue
            }

            receivedBytes += UInt64(interfaceData.pointee.ifi_ibytes)
            sentBytes += UInt64(interfaceData.pointee.ifi_obytes)
        }

        return Counters(receivedBytes: receivedBytes, sentBytes: sentBytes)
    }
}

private final class GPUSampler {
    private let candidateClasses = ["IOAccelerator", "IOGPU"]
    private let preferredStatisticKeys = [
        "Device Utilization %",
        "GPU Core Utilization",
        "Renderer Utilization %",
        "Tiler Utilization %",
    ]

    func usage() -> Double? {
        for candidateClass in candidateClasses {
            if let usage = usage(forServiceClass: candidateClass) {
                return usage
            }
        }

        return nil
    }

    private func usage(forServiceClass serviceClass: String) -> Double? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(serviceClass), &iterator)

        guard result == KERN_SUCCESS else {
            return nil
        }

        defer {
            IOObjectRelease(iterator)
        }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let statistics = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any],
                let usage = Self.extractUsage(from: statistics, preferredKeys: preferredStatisticKeys) {
                IOObjectRelease(service)
                return usage
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return nil
    }

    private static func extractUsage(from statistics: [String: Any], preferredKeys: [String]) -> Double? {
        for key in preferredKeys {
            if let value = statistics[key] as? NSNumber {
                return normalizePercent(value.doubleValue)
            }
        }

        for (key, value) in statistics {
            guard key.localizedCaseInsensitiveContains("utilization"), key.contains("%"),
                let number = value as? NSNumber else {
                continue
            }

            return normalizePercent(number.doubleValue)
        }

        return nil
    }

    private static func normalizePercent(_ rawValue: Double) -> Double {
        let ratio = rawValue > 1 ? rawValue / 100 : rawValue
        return min(max(ratio, 0), 1)
    }
}
