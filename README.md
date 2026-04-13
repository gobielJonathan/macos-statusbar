# macOS Status Bar

A native macOS status bar application that displays real-time system information:

- **Network usage** — live upload and download rates
- **CPU usage** — combined utilisation across all cores, updated every 2 seconds
- **Memory usage** — used RAM vs. total physical memory
- **Calendar** — upcoming events for the rest of today (requires Calendar permission)

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ / Xcode 15+

## Build & Run

```sh
# Debug build
swift build

# Release build
swift build -c release

# Run directly
swift run StatusBar

# Or run the compiled binary
.build/release/StatusBar
```

Open in Xcode:

```sh
open Package.swift
```

## Architecture

```
Sources/
├── StatusBarCore/          # Platform-agnostic library (models, protocols, formatters)
│   ├── Models.swift        # CPUInfo, MemoryInfo, NetworkInfo, CalendarEvent
│   ├── Protocols.swift     # CPUMonitoring, MemoryMonitoring, NetworkMonitoring, CalendarMonitoring
│   └── Formatters.swift    # Byte / percentage / date formatting utilities
└── StatusBarApp/           # macOS executable (AppKit + EventKit)
    ├── main.swift          # NSApplication entry point
    ├── AppDelegate.swift   # App lifecycle
    ├── StatusBarController.swift  # NSStatusItem, menu, refresh loop
    ├── CPUMonitor.swift    # host_processor_info (mach)
    ├── MemoryMonitor.swift # host_statistics64 (mach)
    ├── NetworkMonitor.swift# getifaddrs (if_data)
    └── CalendarMonitor.swift # EKEventStore (EventKit)
Tests/
└── StatusBarTests/
    └── FormattersTests.swift  # Unit tests for Formatters and model clamping
```

## Status Bar Display

The status bar button shows a compact live summary:

```
⬆0 B/s  ⬇0 B/s  CPU:3%  RAM:45%  Mon Apr 13
```

Click the item to open a menu with more detail:

```
System Status
─────────────────────
CPU Usage:  3%
Memory:  6.1 GB / 16.0 GB  (38%)
─────────────────────
Upload:    0 B/s
Download:  0 B/s
─────────────────────
Today's Events
  14:00  Team standup
  16:30  1:1 with manager
─────────────────────
Quit StatusBar
```

## Permissions

On first launch the application will prompt for **Calendar** access.  
This can be managed in **System Settings → Privacy & Security → Calendars**.  
The app works without calendar access — the events section will simply be empty.

## Running Tests

```sh
swift test
```