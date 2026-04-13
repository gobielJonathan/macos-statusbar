import AppKit
import SwiftUI

@main
struct MacOSBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var holidayStore = HolidayStore()

    var body: some Scene {
        MenuBarExtra {
            MetricsMenuView(snapshot: monitor.snapshot, holidayStore: holidayStore)
        } label: {
            StatusBarLabel(snapshot: monitor.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
