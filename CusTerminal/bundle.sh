#!/usr/bin/env bash
# swift build 결과물을 macOS .app 번들로 감싼다.
# SwiftUI 앱은 번들 안에서 실행되어야 창이 뜬다.
set -e
cd "$(dirname "$0")"
swift build -c release
BIN=.build/release/CusTerminal
APP=.build/release/CusTerminal.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CusTerminal"

# 앱 아이콘 (.icns) 이 없으면 즉석 생성.
if [ ! -f AppIcon.icns ]; then
  echo "→ AppIcon.icns 없음. 생성 중..."
  ./make-icns.sh
fi
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CusTerminal</string>
  <key>CFBundleDisplayName</key><string>CusTerminal</string>
  <key>CFBundleIdentifier</key><string>com.silverslab.custerminal</string>
  <key>CFBundleExecutable</key><string>CusTerminal</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Finder 가 아이콘 캐시를 즉시 갱신하도록 힌트.
touch "$APP"
echo "번들 생성 완료: $(pwd)/$APP"
echo "실행: open '$(pwd)/$APP' --args --layout 4,3"
