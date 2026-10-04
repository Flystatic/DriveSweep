#!/bin/zsh
# Builds build/Ejectus-<version>.dmg: drag-to-Applications installer.
set -euo pipefail
cd "${0:A:h}"
./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Ejectus.app/Contents/Info.plist)
STAGE=build/dmg
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R build/Ejectus.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.txt "$STAGE/How to Install.txt"
DMG="build/Ejectus-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "Ejectus" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
rm -rf "$STAGE"
echo "Built $DMG"
