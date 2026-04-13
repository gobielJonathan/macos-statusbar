#if os(macOS)
import Darwin
import Foundation
import StatusBarCore

/// Measures network throughput by walking the interface list with `getifaddrs`
/// and computing the byte-count deltas between consecutive readings.
final class NetworkMonitor: NetworkMonitoring {

    private var previousBytes: (inBytes: UInt64, outBytes: UInt64)?
    private var previousTime:  Date?

    func networkInfo() -> NetworkInfo {
        guard let (totalIn, totalOut) = readInterfaceBytes() else {
            return NetworkInfo(uploadBytesPerSec: 0, downloadBytesPerSec: 0)
        }

        let now  = Date()
        var uploadRate:   Double = 0
        var downloadRate: Double = 0

        if let prev = previousBytes, let prevTime = previousTime {
            let elapsed = now.timeIntervalSince(prevTime)
            if elapsed > 0 {
                // Guard against counter wraps (32-bit ifi_ibytes/ifi_obytes).
                let inDelta  = totalIn  >= prev.inBytes  ? totalIn  - prev.inBytes  : 0
                let outDelta = totalOut >= prev.outBytes ? totalOut - prev.outBytes : 0
                downloadRate = Double(inDelta)  / elapsed
                uploadRate   = Double(outDelta) / elapsed
            }
        }

        previousBytes = (inBytes: totalIn, outBytes: totalOut)
        previousTime  = now

        return NetworkInfo(uploadBytesPerSec: uploadRate, downloadBytesPerSec: downloadRate)
    }

    // MARK: - Helpers

    private func readInterfaceBytes() -> (inBytes: UInt64, outBytes: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var totalIn:  UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr = ifaddr

        while let current = ptr {
            let iface = current.pointee
            if iface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = iface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                totalIn  += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }
            ptr = iface.ifa_next
        }

        return (inBytes: totalIn, outBytes: totalOut)
    }
}
#endif
