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

# ad-hoc 코드 서명 (Apple 계정 불필요, 무료).
# --identifier 를 고정해 재빌드해도 macOS 가 "같은 앱" 으로 인식 → 매번 권한 재요청 안 뜸.
# --preserve-metadata 로 기존 entitlements 유지.
codesign --force --deep --sign - \
  --identifier com.silverslab.custerminal \
  --options runtime \
  "$APP" 2>/dev/null || {
  echo "⚠️  codesign 실패 (계속 진행)"
}

# 로컬 빌드는 원래 quarantine 없지만, 혹시 남아있으면 제거.
xattr -cr "$APP" 2>/dev/null || true

# Finder 가 아이콘 캐시를 즉시 갱신하도록 힌트.
touch "$APP"
echo "번들 생성 완료: $(pwd)/$APP"
echo "실행: open '$(pwd)/$APP' --args --layout 4,3"
