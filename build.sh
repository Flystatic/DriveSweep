#!/bin/zsh
# Builds build/DriveSweep.app (Apple silicon + Intel).
set -euo pipefail
cd "${0:A:h}"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DriveSweep"

APP=build/DriveSweep.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DriveSweep"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>local.drivesweep</string>
    <key>CFBundleName</key><string>DriveSweep</string>
    <key>CFBundleExecutable</key><string>DriveSweep</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key><dict><key>default</key><string>Clean Junk Files</string></dict>
            <key>NSMessage</key><string>cleanJunk</string>
            <key>NSPortName</key><string>DriveSweep</string>
            <key>NSRequiredContext</key><dict/>
            <key>NSSendFileTypes</key><array><string>public.volume</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Root helper (same binary, run with --helper). Registered via SMAppService.daemon.
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cat > "$APP/Contents/Library/LaunchDaemons/local.drivesweep.helper.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.drivesweep.helper</string>
    <key>BundleProgram</key><string>Contents/MacOS/DriveSweep</string>
    <key>ProgramArguments</key><array><string>DriveSweep</string><string>--helper</string></array>
    <key>MachServices</key><dict><key>local.drivesweep.helper</key><true/></dict>
    <key>AssociatedBundleIdentifiers</key><array><string>local.drivesweep</string></array>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier local.drivesweep "$APP"
echo "Built $APP"
