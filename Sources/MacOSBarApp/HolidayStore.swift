import Combine
import Foundation

enum HolidayType: String, Decodable, Sendable {
    case holiday
    case leave

    var displayName: String {
        switch self {
        case .holiday:
            return "Holiday"
        case .leave:
            return "Leave"
        }
    }
}

struct HolidayMarker: Sendable {
    let items: [HolidayItem]

    var helpText: String {
        items.map { "\($0.type.displayName): \($0.name)" }
            .joined(separator: "\n")
    }
}

struct HolidayMonthEntry: Identifiable, Sendable {
    let id: String
    let dateKey: HolidayDateKey
    let item: HolidayItem
}

struct HolidayDateKey: Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init?(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }

    init?(apiDateString: String) {
        let parts = apiDateString.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }
}

struct HolidayItem: Decodable, Sendable {
    let date: String
    let name: String
    let type: HolidayType
}

private struct HolidaysResponse: Decodable {
    let data: [HolidayItem]
}

enum HolidayAPI {
    static func fetch(year: Int) async throws -> [HolidayItem] {
        var components = URLComponents(string: "https://tanggalmerah.upset.dev/api/holidays")
        components?.queryItems = [URLQueryItem(name: "year", value: String(year))]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(HolidaysResponse.self, from: data).data
    }
}

@MainActor
final class HolidayStore: ObservableObject {
    @Published private var itemsByDate: [HolidayDateKey: [HolidayItem]] = [:]

    private var loadedYears: Set<Int> = []
    private var loadingYears: Set<Int> = []

    func load(year: Int) async {
        guard !loadedYears.contains(year), !loadingYears.contains(year) else {
            return
        }

        loadingYears.insert(year)
        defer {
            loadingYears.remove(year)
        }

        do {
            let items = try await HolidayAPI.fetch(year: year)
            var mergedItems = itemsByDate

            for item in items {
                guard let key = HolidayDateKey(apiDateString: item.date) else {
                    continue
                }

                mergedItems[key, default: []].append(item)
            }

            itemsByDate = mergedItems
            loadedYears.insert(year)
        } catch {
            // Ignore transient network failures; navigating the calendar can retry.
        }
    }

    func marker(for date: Date?, calendar: Calendar = .autoupdatingCurrent) -> HolidayMarker? {
        guard
            let date,
            let key = HolidayDateKey(date: date, calendar: calendar),
            let items = itemsByDate[key],
            !items.isEmpty
        else {
            return nil
        }

        return HolidayMarker(items: items)
    }

    func entries(forMonth month: Date, calendar: Calendar = .autoupdatingCurrent) -> [HolidayMonthEntry] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let year = components.year, let month = components.month else {
            return []
        }

        return itemsByDate
            .filter { $0.key.year == year && $0.key.month == month }
            .flatMap { key, items in
                items.enumerated().map { index, item in
                    HolidayMonthEntry(
                        id: "\(key.year)-\(key.month)-\(key.day)-\(index)-\(item.type.rawValue)-\(item.name)",
                        dateKey: key,
                        item: item
                    )
                }
            }
            .sorted {
                if $0.dateKey.day != $1.dateKey.day {
                    return $0.dateKey.day < $1.dateKey.day
                }

                return $0.item.name.localizedStandardCompare($1.item.name) == .orderedAscending
            }
    }
}
