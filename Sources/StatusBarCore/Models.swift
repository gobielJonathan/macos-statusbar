import Foundation

// MARK: - CPU

/// A snapshot of CPU utilisation.
public struct CPUInfo {
    /// Fraction of CPU currently in use across all cores (0.0 – 1.0).
    public let usage: Double

    public init(usage: Double) {
        self.usage = max(0.0, min(1.0, usage))
    }
}

// MARK: - Memory

/// A snapshot of physical memory usage.
public struct MemoryInfo {
    /// Bytes currently in use (wired + active + inactive + compressed).
    public let usedBytes: UInt64
    /// Total installed physical memory in bytes.
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    /// Used memory expressed as a fraction (0.0 – 1.0).
    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

// MARK: - Network

/// Instantaneous network throughput (bytes per second).
public struct NetworkInfo {
    /// Current upload rate in bytes per second.
    public let uploadBytesPerSec: Double
    /// Current download rate in bytes per second.
    public let downloadBytesPerSec: Double

    public init(uploadBytesPerSec: Double, downloadBytesPerSec: Double) {
        self.uploadBytesPerSec = max(0, uploadBytesPerSec)
        self.downloadBytesPerSec = max(0, downloadBytesPerSec)
    }
}

// MARK: - Calendar

/// A single calendar event.
public struct CalendarEvent {
    public let title: String
    public let startDate: Date

    public init(title: String, startDate: Date) {
        self.title = title
        self.startDate = startDate
    }
}
