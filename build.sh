#!/bin/zsh
# Builds SpaceClock.app into ~/Applications.
set -e
cd "$(dirname "$0")"

mkdir -p "$HOME/Applications"
APP="$HOME/Applications/SpaceClock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O SpaceClock.swift -o "$APP/Contents/MacOS/SpaceClock" -framework AppKit -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SpaceClock</string>
    <key>CFBundleDisplayName</key><string>SpaceClock</string>
    <key>CFBundleIdentifier</key><string>io.github.dsatyam09.SpaceClock</string>
    <key>CFBundleExecutable</key><string>SpaceClock</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Strip Finder/iCloud metadata, which codesign rejects, then sign locally (ad-hoc).
xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "Built $APP"
echo "Open it with: open \"$APP\""
