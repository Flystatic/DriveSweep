#!/bin/zsh
# Builds build/DriveSweep-<version>.dmg: drag-to-Applications installer.
set -euo pipefail
cd "${0:A:h}"
./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/DriveSweep.app/Contents/Info.plist)
STAGE=build/dmg
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R build/DriveSweep.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.txt "$STAGE/How to Install.txt"
DMG="build/DriveSweep-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "DriveSweep" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"
echo "Built $DMG"
