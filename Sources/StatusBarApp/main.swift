import Foundation

#if os(macOS)
import AppKit

let app = NSApplication.shared
// Run as an accessory application – no Dock icon, no main window.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

#else
fputs("StatusBar requires macOS 13 or later.\n", stderr)
exit(1)
#endif
