#!/bin/sh
# Builds Lumo.app and installs it to /Applications.
set -e
cd "$(dirname "$0")"
APP=build/Lumo.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources build/Lumo.iconset

swiftc -O Lumo.swift -o $APP/Contents/MacOS/Lumo

swift icon.swift build/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon.png --out build/Lumo.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon.png --out build/Lumo.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/Lumo.iconset -o $APP/Contents/Resources/Lumo.icns

cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.lumo</string>
<key>CFBundleName</key><string>Lumo</string>
<key>CFBundleExecutable</key><string>Lumo</string>
<key>CFBundleIconFile</key><string>Lumo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSLocalNetworkUsageDescription</key><string>Lumo talks to your WiZ bulbs on the local network.</string>
</dict></plist>
EOF
codesign -s - --force $APP

pkill -x Lumo && sleep 1 || true
rm -rf /Applications/Lumo.app && cp -R $APP /Applications/
open /Applications/Lumo.app
