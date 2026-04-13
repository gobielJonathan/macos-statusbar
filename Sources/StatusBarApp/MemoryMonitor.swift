#if os(macOS)
import Darwin
import Foundation
import StatusBarCore

/// Reports physical memory usage via the mach `host_statistics64` API.
final class MemoryMonitor: MemoryMonitoring {

    func memoryInfo() -> MemoryInfo {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory

        guard result == KERN_SUCCESS else {
            return MemoryInfo(usedBytes: 0, totalBytes: total)
        }

        let pageSize = UInt64(vm_page_size)
        let free     = UInt64(stats.free_count) * pageSize
        let used     = total > free ? total - free : 0

        return MemoryInfo(usedBytes: used, totalBytes: total)
    }
}
#endif
