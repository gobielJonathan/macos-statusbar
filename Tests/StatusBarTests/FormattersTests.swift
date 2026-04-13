import XCTest
@testable import StatusBarCore

final class FormattersTests: XCTestCase {

    // MARK: - formatBytes

    func testFormatBytes_zero() {
        XCTAssertEqual(Formatters.formatBytes(0), "0 B")
    }

    func testFormatBytes_bytes() {
        XCTAssertEqual(Formatters.formatBytes(512), "512 B")
    }

    func testFormatBytes_oneKilobyte() {
        XCTAssertEqual(Formatters.formatBytes(1_024), "1 KB")
    }

    func testFormatBytes_kilobytes() {
        // 512 000 / 1024 = 500 KB exactly
        XCTAssertEqual(Formatters.formatBytes(512_000), "500 KB")
    }

    func testFormatBytes_oneMegabyte() {
        XCTAssertEqual(Formatters.formatBytes(1_048_576), "1 MB")
    }

    func testFormatBytes_twoMegabytes() {
        XCTAssertEqual(Formatters.formatBytes(2_097_152), "2 MB")
    }

    func testFormatBytes_oneGigabyte() {
        XCTAssertEqual(Formatters.formatBytes(1_073_741_824), "1.0 GB")
    }

    func testFormatBytes_eightGigabytes() {
        XCTAssertEqual(Formatters.formatBytes(8_589_934_592), "8.0 GB")
    }

    // MARK: - formatBytesPerSecond

    func testFormatBytesPerSecond_zero() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(0), "0 B/s")
    }

    func testFormatBytesPerSecond_bytesPerSecond() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(500), "500 B/s")
    }

    func testFormatBytesPerSecond_oneKilobytePerSecond() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(1_024), "1 KB/s")
    }

    func testFormatBytesPerSecond_kilobytesPerSecond() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(512_000), "500 KB/s")
    }

    func testFormatBytesPerSecond_oneMegabytePerSecond() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(1_048_576), "1.0 MB/s")
    }

    func testFormatBytesPerSecond_tenMegabytesPerSecond() {
        XCTAssertEqual(Formatters.formatBytesPerSecond(10_485_760), "10.0 MB/s")
    }

    // MARK: - formatPercentage

    func testFormatPercentage_zero() {
        XCTAssertEqual(Formatters.formatPercentage(0.0), "0%")
    }

    func testFormatPercentage_fifty() {
        XCTAssertEqual(Formatters.formatPercentage(0.5), "50%")
    }

    func testFormatPercentage_hundred() {
        XCTAssertEqual(Formatters.formatPercentage(1.0), "100%")
    }

    func testFormatPercentage_clampsBelowZero() {
        XCTAssertEqual(Formatters.formatPercentage(-0.5), "0%")
    }

    func testFormatPercentage_clampsAboveOne() {
        XCTAssertEqual(Formatters.formatPercentage(2.0), "100%")
    }

    func testFormatPercentage_quarter() {
        XCTAssertEqual(Formatters.formatPercentage(0.25), "25%")
    }

    // MARK: - MemoryInfo.usedFraction

    func testMemoryInfo_usedFraction_half() {
        let info = MemoryInfo(usedBytes: 4_294_967_296, totalBytes: 8_589_934_592)
        XCTAssertEqual(info.usedFraction, 0.5, accuracy: 0.001)
    }

    func testMemoryInfo_usedFraction_zeroTotal() {
        let info = MemoryInfo(usedBytes: 0, totalBytes: 0)
        XCTAssertEqual(info.usedFraction, 0.0)
    }

    func testMemoryInfo_usedFraction_full() {
        let info = MemoryInfo(usedBytes: 8_589_934_592, totalBytes: 8_589_934_592)
        XCTAssertEqual(info.usedFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - CPUInfo clamping

    func testCPUInfo_clampsBelowZero() {
        let info = CPUInfo(usage: -0.5)
        XCTAssertEqual(info.usage, 0.0)
    }

    func testCPUInfo_clampsAboveOne() {
        let info = CPUInfo(usage: 1.5)
        XCTAssertEqual(info.usage, 1.0)
    }

    func testCPUInfo_midRange() {
        let info = CPUInfo(usage: 0.75)
        XCTAssertEqual(info.usage, 0.75, accuracy: 0.001)
    }

    // MARK: - NetworkInfo non-negative

    func testNetworkInfo_nonNegative() {
        let info = NetworkInfo(uploadBytesPerSec: -100, downloadBytesPerSec: -200)
        XCTAssertEqual(info.uploadBytesPerSec, 0.0)
        XCTAssertEqual(info.downloadBytesPerSec, 0.0)
    }
}
