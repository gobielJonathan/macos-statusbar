#if os(macOS)
import AppKit
import StatusBarCore

/// Owns the NSStatusItem and refreshes all displayed metrics every 2 seconds.
final class StatusBarController {

    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let cpuMonitor: CPUMonitor
    private let memoryMonitor: MemoryMonitor
    private let networkMonitor: NetworkMonitor
    private let calendarMonitor: CalendarMonitor

    // Persistent menu items whose titles are updated on each tick.
    private let cpuMenuItem      = NSMenuItem(title: "CPU: –",       action: nil, keyEquivalent: "")
    private let memMenuItem      = NSMenuItem(title: "Memory: –",    action: nil, keyEquivalent: "")
    private let uploadMenuItem   = NSMenuItem(title: "Upload: –",    action: nil, keyEquivalent: "")
    private let downloadMenuItem = NSMenuItem(title: "Download: –",  action: nil, keyEquivalent: "")
    private let calHeaderItem    = NSMenuItem(title: "Today's Events", action: nil, keyEquivalent: "")

    // Dynamically added/removed calendar event rows.
    private var calEventItems: [NSMenuItem] = []

    private var refreshTimer: Timer?

    // MARK: - Initialisation

    init() {
        statusItem     = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        cpuMonitor     = CPUMonitor()
        memoryMonitor  = MemoryMonitor()
        networkMonitor = NetworkMonitor()
        calendarMonitor = CalendarMonitor()

        buildMenu()
        calendarMonitor.requestAccess()
        scheduleRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Menu construction

    private func buildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "System Status", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        cpuMenuItem.isEnabled = false
        memMenuItem.isEnabled = false
        menu.addItem(cpuMenuItem)
        menu.addItem(memMenuItem)
        menu.addItem(.separator())

        uploadMenuItem.isEnabled   = false
        downloadMenuItem.isEnabled = false
        menu.addItem(uploadMenuItem)
        menu.addItem(downloadMenuItem)
        menu.addItem(.separator())

        calHeaderItem.isEnabled = false
        menu.addItem(calHeaderItem)
        // Calendar event rows are inserted dynamically after calHeaderItem.

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit StatusBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Refresh loop

    private func scheduleRefresh() {
        refresh()   // immediate first update
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let cpu    = cpuMonitor.cpuUsage()
        let mem    = memoryMonitor.memoryInfo()
        let net    = networkMonitor.networkInfo()
        let events = calendarMonitor.todaysEvents()

        updateButton(cpu: cpu, mem: mem, net: net)
        updateMenuItems(cpu: cpu, mem: mem, net: net, events: events)
    }

    // MARK: - Button title

    private func updateButton(cpu: Double, mem: MemoryInfo, net: NetworkInfo) {
        let up   = Formatters.formatBytesPerSecond(net.uploadBytesPerSec)
        let down = Formatters.formatBytesPerSecond(net.downloadBytesPerSec)
        let cpuPct = Formatters.formatPercentage(cpu)
        let memPct = Formatters.formatPercentage(mem.usedFraction)
        let date   = Formatters.formatStatusBarDate(Date())

        statusItem.button?.title = "⬆\(up)  ⬇\(down)  CPU:\(cpuPct)  RAM:\(memPct)  \(date)"
    }

    // MARK: - Menu item text

    private func updateMenuItems(cpu: Double, mem: MemoryInfo, net: NetworkInfo, events: [CalendarEvent]) {
        cpuMenuItem.title = "CPU Usage:  \(Formatters.formatPercentage(cpu))"

        let used  = Formatters.formatBytes(mem.usedBytes)
        let total = Formatters.formatBytes(mem.totalBytes)
        let pct   = Formatters.formatPercentage(mem.usedFraction)
        memMenuItem.title = "Memory:  \(used) / \(total)  (\(pct))"

        uploadMenuItem.title   = "Upload:    \(Formatters.formatBytesPerSecond(net.uploadBytesPerSec))"
        downloadMenuItem.title = "Download:  \(Formatters.formatBytesPerSecond(net.downloadBytesPerSec))"

        refreshCalendarRows(events: events)
    }

    // MARK: - Calendar rows

    private func refreshCalendarRows(events: [CalendarEvent]) {
        guard let menu = statusItem.menu,
              let headerIndex = menu.items.firstIndex(of: calHeaderItem) else { return }

        // Remove previous event rows.
        for item in calEventItems {
            menu.removeItem(item)
        }
        calEventItems.removeAll()

        if events.isEmpty {
            let none = NSMenuItem(title: "  No upcoming events today", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.insertItem(none, at: headerIndex + 1)
            calEventItems.append(none)
        } else {
            for (offset, event) in events.enumerated() {
                let time = Formatters.formatTime(event.startDate)
                let row  = NSMenuItem(title: "  \(time)  \(event.title)", action: nil, keyEquivalent: "")
                row.isEnabled = false
                menu.insertItem(row, at: headerIndex + 1 + offset)
                calEventItems.append(row)
            }
        }
    }
}
#endif
