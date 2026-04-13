import Foundation

/// Provides CPU utilisation data.
public protocol CPUMonitoring {
    /// Returns overall CPU usage as a fraction from 0.0 (idle) to 1.0 (fully busy).
    /// Implementations should calculate the delta between consecutive readings so
    /// the value reflects *recent* activity rather than a lifetime average.
    func cpuUsage() -> Double
}

/// Provides physical memory usage data.
public protocol MemoryMonitoring {
    /// Returns a snapshot of current memory usage.
    func memoryInfo() -> MemoryInfo
}

/// Provides network throughput data.
public protocol NetworkMonitoring {
    /// Returns the current upload and download rates in bytes per second.
    func networkInfo() -> NetworkInfo
}

/// Provides calendar event data for the remainder of today.
public protocol CalendarMonitoring {
    /// Requests calendar access from the operating system (idempotent).
    func requestAccess()
    /// Returns upcoming events between now and midnight, up to a reasonable limit.
    func todaysEvents() -> [CalendarEvent]
}
