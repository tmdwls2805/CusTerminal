#!/usr/bin/env bash
# icon-1024.png → AppIcon.icns 로 변환.
# 없으면 make-icon.swift 를 실행해서 먼저 만든다.
set -e
cd "$(dirname "$0")"

SRC=icon-1024.png
if [ ! -f "$SRC" ]; then
  echo "→ icon-1024.png 없음. 생성 중..."
  swift make-icon.swift
fi

ICONSET=AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# macOS 표준 아이콘 세트: 16, 32, 64, 128, 256, 512, 1024 (@1x, @2x).
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"     >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"  >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"     >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"  >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"   >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"   >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"   >/dev/null
cp "$SRC" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET"
echo "✅ 생성: $(pwd)/AppIcon.icns"
