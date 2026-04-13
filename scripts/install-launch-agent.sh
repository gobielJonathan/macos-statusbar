#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
APP_DIR="$HOME/Library/Application Support/MacOSBar"
BINARY_PATH="$APP_DIR/MacOSBar"
LOG_DIR="$APP_DIR/logs"
PLIST_PATH="$HOME/Library/LaunchAgents/com.gobielj.macosbar.plist"
LABEL="com.gobielj.macosbar"

mkdir -p "$APP_DIR" "$LOG_DIR" "$HOME/Library/LaunchAgents"

cd "$PROJECT_DIR"
swift build -c release
cp "$PROJECT_DIR/.build/release/MacOSBar" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/stderr.log</string>
    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed $LABEL"
echo "Binary: $BINARY_PATH"
echo "LaunchAgent: $PLIST_PATH"
