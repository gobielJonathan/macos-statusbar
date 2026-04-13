import AppKit
import SwiftUI

struct StatusBarLabel: View {
    let snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 10) {
            MetricChip(systemName: "dot.radiowaves.left.and.right", value: networkValue)
            MetricChip(systemName: "memorychip", value: MetricFormatters.percent(snapshot.memory?.usageRatio))
            MetricChip(systemName: "cpu", value: MetricFormatters.percent(snapshot.cpuUsage?.totalRatio))
            MetricChip(systemName: "display", value: MetricFormatters.percent(snapshot.gpuUsage))
            MetricChip(systemName: "calendar", value: MetricFormatters.statusDate(snapshot.timestamp))
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .lineLimit(1)
        .fixedSize()
    }

    private var networkValue: String {
        let download = MetricFormatters.bandwidth(snapshot.network?.downloadBytesPerSecond)
        let upload = MetricFormatters.bandwidth(snapshot.network?.uploadBytesPerSecond)
        return "\(download)\u{2193} \(upload)\u{2191}"
    }
}

struct MetricsMenuView: View {
    let snapshot: SystemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(MetricFormatters.menuDate(snapshot.timestamp))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            MetricRow(
                systemName: "dot.radiowaves.left.and.right",
                title: "Network",
                value: "\(MetricFormatters.bandwidth(snapshot.network?.downloadBytesPerSecond)) down • \(MetricFormatters.bandwidth(snapshot.network?.uploadBytesPerSecond)) up"
            )
            MetricRow(
                systemName: "memorychip",
                title: "Memory",
                value: memoryValue
            )
            MetricRow(
                systemName: "cpu",
                title: "CPU",
                value: cpuValue
            )
            MetricRow(
                systemName: "display",
                title: "GPU",
                value: "\(MetricFormatters.percent(snapshot.gpuUsage)) active"
            )

            Divider()

            CalendarPanel(referenceDate: snapshot.timestamp)

            Divider()

            Button("Quit MacOSBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 360)
    }

    private var memoryValue: String {
        guard let memory = snapshot.memory else {
            return "--"
        }

        return "\(MetricFormatters.percent(memory.usageRatio)) used • \(MetricFormatters.memory(memory.usedBytes)) of \(MetricFormatters.memory(memory.totalBytes)) • App \(MetricFormatters.memory(memory.appBytes)) • Wired \(MetricFormatters.memory(memory.wiredBytes)) • Compressed \(MetricFormatters.memory(memory.compressedBytes))"
    }

    private var cpuValue: String {
        guard let cpu = snapshot.cpuUsage else {
            return "--"
        }

        return "\(MetricFormatters.percent(cpu.totalRatio)) total • User \(MetricFormatters.percent(cpu.userRatio)) • System \(MetricFormatters.percent(cpu.systemRatio))"
    }
}

private struct MetricChip: View {
    let systemName: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
            Text(value)
                .monospacedDigit()
        }
    }
}

private struct MetricRow: View {
    let systemName: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemName)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(value)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CalendarPanel: View {
    let referenceDate: Date
    @State private var displayedMonth: Date

    private let calendar = Calendar.autoupdatingCurrent
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(referenceDate: Date) {
        self.referenceDate = referenceDate
        _displayedMonth = State(initialValue: MetricFormatters.startOfMonth(for: referenceDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label("Calendar", systemImage: "calendar")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer()

                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(MetricFormatters.monthYear(displayedMonth))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(minWidth: 110)

                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(MetricFormatters.weekdaySymbols(calendar: calendar), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarSlots) { slot in
                    CalendarCell(slot: slot, isToday: isToday(slot.date))
                }
            }

            HStack {
                Text("Showing \(MetricFormatters.monthYear(displayedMonth))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Today") {
                    displayedMonth = MetricFormatters.startOfMonth(for: referenceDate)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
    }

    private var calendarSlots: [CalendarSlot] {
        MetricFormatters.calendarSlots(for: displayedMonth, calendar: calendar)
    }

    private func shiftMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }

        displayedMonth = MetricFormatters.startOfMonth(for: nextMonth)
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: referenceDate)
    }
}

private struct CalendarCell: View {
    let slot: CalendarSlot
    let isToday: Bool

    var body: some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.accentColor.opacity(0.18))
            }

            Text(slot.label)
                .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(slot.date == nil ? .tertiary : .primary)
                .frame(maxWidth: .infinity, minHeight: 24)
        }
        .frame(height: 24)
    }
}

private struct CalendarSlot: Identifiable {
    let id = UUID()
    let date: Date?
    let label: String
}

@MainActor
private enum MetricFormatters {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let statusDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        return formatter
    }()

    private static let menuDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    static func percent(_ ratio: Double?) -> String {
        guard let ratio else {
            return "--"
        }

        return "\(Int((ratio * 100).rounded()))%"
    }

    static func memory(_ bytes: UInt64?) -> String {
        guard let bytes else {
            return "--"
        }

        return byteFormatter.string(fromByteCount: Int64(bytes))
    }

    static func bandwidth(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else {
            return "--"
        }

        let megabitsPerSecond = max(bytesPerSecond, 0) * 8 / 1_000_000

        let decimals: Int
        switch megabitsPerSecond {
        case 100...:
            decimals = 0
        case 10...:
            decimals = 1
        default:
            decimals = 2
        }

        return String(format: "%.\(decimals)fMb/s", megabitsPerSecond)
    }

    static func statusDate(_ date: Date) -> String {
        statusDateFormatter.string(from: date)
    }

    static func menuDate(_ date: Date) -> String {
        menuDateFormatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func startOfMonth(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func weekdaySymbols(calendar: Calendar = .autoupdatingCurrent) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent

        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        guard !symbols.isEmpty else {
            return ["S", "M", "T", "W", "T", "F", "S"]
        }

        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex]).map {
            String($0.prefix(2))
        }
    }

    static func calendarSlots(for month: Date, calendar: Calendar = .autoupdatingCurrent) -> [CalendarSlot] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }

        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDay)
        let leadingEmptyCells = (weekdayOfFirstDay - calendar.firstWeekday + 7) % 7

        var slots = Array(
            repeating: CalendarSlot(date: nil, label: ""),
            count: leadingEmptyCells
        )

        for day in monthRange {
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = day
            let dayDate = calendar.date(from: components)
            slots.append(CalendarSlot(date: dayDate, label: String(day)))
        }

        let trailingCells = (7 - (slots.count % 7)) % 7
        if trailingCells > 0 {
            slots.append(contentsOf: Array(repeating: CalendarSlot(date: nil, label: ""), count: trailingCells))
        }

        return slots
    }
}
