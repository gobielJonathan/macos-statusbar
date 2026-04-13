#if os(macOS)
import Darwin
import StatusBarCore

/// Measures per-CPU-core utilisation using the mach `host_processor_info` API.
///
/// On the first call the method returns 0.0 because no previous reading exists.
/// Subsequent calls return the fraction of time spent outside of the idle state
/// since the last reading, averaged across all cores.
final class CPUMonitor: CPUMonitoring {

    private var previousTicks: [Int32] = []

    func cpuUsage() -> Double {
        var numCPUs:   natural_t = 0
        var cpuInfoPtr: processor_info_array_t? = nil
        var numCPUInfo: mach_msg_type_number_t  = 0

        guard host_processor_info(
                mach_host_self(),
                PROCESSOR_CPU_LOAD_INFO,
                &numCPUs,
                &cpuInfoPtr,
                &numCPUInfo
              ) == KERN_SUCCESS,
              let cpuInfo = cpuInfoPtr
        else {
            return 0.0
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let numCores    = Int(numCPUs)
        let statesCount = Int(CPU_STATE_MAX)    // USER, SYSTEM, NICE, IDLE
        let totalCount  = numCores * statesCount
        let current     = (0..<totalCount).map { cpuInfo[$0] }

        var totalUsage  = 0.0
        var validCores  = 0

        if previousTicks.count == totalCount {
            for core in 0..<numCores {
                let base = core * statesCount

                func delta(_ state: Int32) -> Double {
                    Double(max(0, current[base + Int(state)] - previousTicks[base + Int(state)]))
                }

                let dUser   = delta(CPU_STATE_USER)
                let dSystem = delta(CPU_STATE_SYSTEM)
                let dNice   = delta(CPU_STATE_NICE)
                let dIdle   = delta(CPU_STATE_IDLE)
                let dTotal  = dUser + dSystem + dNice + dIdle

                if dTotal > 0 {
                    totalUsage += (dUser + dSystem + dNice) / dTotal
                    validCores += 1
                }
            }
        }

        previousTicks = current
        return validCores > 0 ? totalUsage / Double(validCores) : 0.0
    }
}
#endif
