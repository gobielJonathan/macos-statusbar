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
    @ObservedObject var holidayStore: HolidayStore

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

            CalendarPanel(referenceDate: snapshot.timestamp, holidayStore: holidayStore)

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
    @ObservedObject var holidayStore: HolidayStore
    @State private var displayedMonth: Date
    @State private var selectedDate: Date?

    private let calendar = Calendar.autoupdatingCurrent
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(referenceDate: Date, holidayStore: HolidayStore) {
        self.referenceDate = referenceDate
        self.holidayStore = holidayStore
        _displayedMonth = State(initialValue: MetricFormatters.startOfMonth(for: referenceDate))
        _selectedDate = State(initialValue: referenceDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Label("Calendar", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Spacer()

                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text(MetricFormatters.monthYear(displayedMonth))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(minWidth: 96)

                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Self.columns, spacing: 5) {
                ForEach(MetricFormatters.weekdaySymbols(calendar: calendar), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarSlots) { slot in
                    CalendarCell(
                        slot: slot,
                        isToday: isToday(slot.date),
                        isSelected: isSelected(slot.date),
                        marker: holidayStore.marker(for: slot.date, calendar: calendar),
                        action: {
                            guard let date = slot.date else {
                                return
                            }

                            selectedDate = date
                        }
                    )
                }
            }

            HStack {
                Spacer()
                Button("Today") {
                    displayedMonth = MetricFormatters.startOfMonth(for: referenceDate)
                    selectedDate = referenceDate
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            }

            if !selectedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedEntries) { entry in
                        HolidayDescriptionRow(entry: entry, showDay: false)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.08))
                )
            }
        }
        .task(id: displayedYear) {
            await holidayStore.load(year: displayedYear)
        }
    }

    private var calendarSlots: [CalendarSlot] {
        MetricFormatters.calendarSlots(for: displayedMonth, calendar: calendar)
    }

    private var displayedYear: Int {
        calendar.component(.year, from: displayedMonth)
    }

    private var selectedEntries: [HolidayMonthEntry] {
        guard let selectedDate else {
            return []
        }

        guard let key = HolidayDateKey(date: selectedDate, calendar: calendar) else {
            return []
        }

        return holidayStore.entries(forMonth: displayedMonth, calendar: calendar)
            .filter {
                $0.dateKey.year == key.year &&
                    $0.dateKey.month == key.month &&
                    $0.dateKey.day == key.day
            }
    }

    private func shiftMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }

        displayedMonth = MetricFormatters.startOfMonth(for: nextMonth)
        selectedDate = nil
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: referenceDate)
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date, let selectedDate else {
            return false
        }

        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
}

private struct HolidayDescriptionRow: View {
    let entry: HolidayMonthEntry
    var showDay = true

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if showDay {
                Text(String(entry.dateKey.day))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 24, alignment: .leading)
            }

            Text(entry.item.type.displayName.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.12))
                )

            Text(entry.item.name)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }
}

private struct CalendarCell: View {
    let slot: CalendarSlot
    let isToday: Bool
    let isSelected: Bool
    let marker: HolidayMarker?
    let action: () -> Void

    var body: some View {
        let content = Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.28))
                } else if isToday {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.18))
                }

                VStack(spacing: 1) {
                    Text(slot.label)
                        .font(.system(size: 11, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                        .foregroundStyle(slot.date == nil ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, minHeight: 18)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 5, height: 5)
                        .opacity(marker == nil ? 0 : 1)
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
        }
        .frame(height: 28)
        .buttonStyle(.plain)
        .disabled(slot.date == nil)

        if let marker {
            content.help(marker.helpText)
        } else {
            content
        }
    }
}

private struct CalendarSlot: Identifiable {
    let id: Int
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

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
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
        let symbols = weekdayFormatter.shortStandaloneWeekdaySymbols ?? weekdayFormatter.shortWeekdaySymbols ?? []
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

        var slots: [CalendarSlot] = []
        slots.reserveCapacity(leadingEmptyCells + monthRange.count + 7)

        for index in 0..<leadingEmptyCells {
            slots.append(CalendarSlot(id: index, date: nil, label: ""))
        }

        for day in monthRange {
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = day
            let dayDate = calendar.date(from: components)
            slots.append(CalendarSlot(id: slots.count, date: dayDate, label: String(day)))
        }

        let trailingCells = (7 - (slots.count % 7)) % 7
        if trailingCells > 0 {
            let startIndex = slots.count
            for offset in 0..<trailingCells {
                slots.append(CalendarSlot(id: startIndex + offset, date: nil, label: ""))
            }
        }

        return slots
    }
}
