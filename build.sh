#!/bin/zsh
# Builds build/Ejectus.app (Apple silicon + Intel).
set -euo pipefail
cd "${0:A:h}"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Ejectus"

APP=build/Ejectus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ejectus"
cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>local.ejectus</string>
    <key>CFBundleName</key><string>Ejectus</string>
    <key>CFBundleExecutable</key><string>Ejectus</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key><dict><key>default</key><string>Clean Junk Files</string></dict>
            <key>NSMessage</key><string>cleanJunk</string>
            <key>NSPortName</key><string>Ejectus</string>
            <key>NSRequiredContext</key><dict/>
            <key>NSSendFileTypes</key><array><string>public.volume</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Root helper (same binary, run with --helper). Registered via SMAppService.daemon.
mkdir -p "$APP/Contents/Library/LaunchDaemons"
cat > "$APP/Contents/Library/LaunchDaemons/local.ejectus.helper.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.ejectus.helper</string>
    <key>BundleProgram</key><string>Contents/MacOS/Ejectus</string>
    <key>ProgramArguments</key><array><string>Ejectus</string><string>--helper</string></array>
    <key>MachServices</key><dict><key>local.ejectus.helper</key><true/></dict>
    <key>AssociatedBundleIdentifiers</key><array><string>local.ejectus</string></array>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier local.ejectus "$APP"
echo "Built $APP"
