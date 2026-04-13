import Foundation

/// Utility functions for formatting system statistics for display in the status bar.
public struct Formatters {

    private init() {}

    // MARK: - Byte counts

    /// Formats a byte count as a human-readable string (e.g. "1.5 GB", "512 MB", "128 KB", "64 B").
    public static func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.0f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }

    // MARK: - Byte rates

    /// Formats a byte-per-second rate as a human-readable string
    /// (e.g. "2.3 MB/s", "768 KB/s", "200 B/s").
    public static func formatBytesPerSecond(_ bytesPerSec: Double) -> String {
        let kbps = bytesPerSec / 1_024
        let mbps = kbps / 1_024

        if mbps >= 1 {
            return String(format: "%.1f MB/s", mbps)
        } else if kbps >= 1 {
            return String(format: "%.0f KB/s", kbps)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }

    // MARK: - Percentages

    /// Formats a fraction (0.0 – 1.0) as a percentage string (e.g. "42%").
    /// Values outside 0–1 are clamped before formatting.
    public static func formatPercentage(_ fraction: Double) -> String {
        let clamped = max(0.0, min(1.0, fraction))
        return String(format: "%.0f%%", clamped * 100)
    }

    // MARK: - Dates & times

    /// Formats a date for display in the status bar (e.g. "Mon Apr 13").
    public static func formatStatusBarDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }

    /// Formats a time for display in the calendar menu (e.g. "14:30").
    public static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
