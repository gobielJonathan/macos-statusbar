#if os(macOS)
import Foundation
import EventKit
import StatusBarCore

/// Fetches upcoming calendar events for the rest of today using EventKit.
///
/// The user will be prompted for calendar access on first launch.
/// Events are returned even without access (the array will simply be empty).
final class CalendarMonitor: CalendarMonitoring {

    private let store        = EKEventStore()
    private var isAuthorized = false

    // MARK: - CalendarMonitoring

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async { self?.isAuthorized = granted }
            }
        } else {
            // Deprecated from macOS 14; kept for macOS 13 compatibility.
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async { self?.isAuthorized = granted }
            }
        }
    }

    func todaysEvents() -> [CalendarEvent] {
        guard isAuthorized else { return [] }

        let now        = Date()
        let endOfDay   = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let predicate  = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let ekEvents   = store.events(matching: predicate)

        return ekEvents.prefix(5).map { CalendarEvent(title: $0.title ?? "Untitled", startDate: $0.startDate) }
    }
}
#endif
