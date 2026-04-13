# MacOSBar

Small macOS menu bar app that shows:

- Network throughput
- Memory usage
- CPU usage
- GPU usage
- Calendar date and time
- A month calendar grid with month and year navigation

The current branch resolves the older parallel `StatusBarApp` rewrite in favor of the existing `MacOSBar` SwiftUI implementation, so there is one menu bar app and one package layout going forward.

## Run

```bash
rtk swift run
```

The app launches as a menu bar utility without a Dock icon.

## Start Automatically After Restart

Install the launch agent:

```bash
chmod +x scripts/install-launch-agent.sh
./scripts/install-launch-agent.sh
```

This builds a release binary into `~/Library/Application Support/MacOSBar/` and registers a per-user LaunchAgent so the menu bar app starts again automatically when you log in after a reboot.

## Notes

- CPU now follows Activity Monitor-style total load as `User + System`.
- Memory now follows Activity Monitor-style `Memory Used` as `App Memory + Wired Memory + Compressed`.
- Network throughput is shown as current download and upload speed in fixed `Mb/s`.
- GPU usage is read from the `IOAccelerator` performance statistics exposed by macOS. If the machine does not expose that field, the app shows `--`.
