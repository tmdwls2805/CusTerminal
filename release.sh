#!/usr/bin/env bash
# GitHub Release 생성 자동화.
# 사용: ./release.sh v0.1.1 [--draft]
#
# 순서:
#   1. CusTerminal.app 빌드 (bundle.sh) → 아이콘 포함
#   2. .app + Applications 심볼릭 링크 담긴 DMG 생성 (hdiutil)
#   3. gh release create 로 GitHub Release 생성 + dmg 첨부
#
# 요구사항: gh CLI 설치 & 로그인 (gh auth login)

set -e

TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "사용: $0 <tag> [--draft]"
  echo "예:   $0 v0.1.1"
  echo "      $0 v0.1.1 --draft"
  exit 1
fi

DRAFT_FLAG=""
if [ "${2:-}" = "--draft" ]; then
  DRAFT_FLAG="--draft"
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# gh 설치/로그인 확인.
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI 가 설치되어 있지 않습니다. brew install gh 후 gh auth login 하세요."
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "❌ gh 에 로그인이 안 되어 있습니다. gh auth login 후 다시 시도하세요."
  exit 1
fi

# 이미 존재하는 태그면 안내.
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "❌ 이미 '$TAG' 릴리즈가 존재합니다. 다른 태그를 쓰거나 gh release delete '$TAG' --cleanup-tag 후 재시도."
  exit 1
fi

# 1. 빌드.
echo "→ 1/3  CusTerminal.app 빌드"
cd CusTerminal
./bundle.sh
APP_PATH="$(pwd)/.build/release/CusTerminal.app"
cd "$ROOT"

# 2. DMG 생성.
echo "→ 2/3  CusTerminal-${TAG}.dmg 생성"
DIST="$ROOT/dist"
mkdir -p "$DIST"
DMG_PATH="$DIST/CusTerminal-${TAG}.dmg"
rm -f "$DMG_PATH"

STAGING="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING/"
# /Applications 심볼릭 링크: DMG 열면 CusTerminal.app 옆에 Applications 폴더가 보임 → 드래그로 설치.
ln -s /Applications "$STAGING/Applications"

# hdiutil 로 압축 DMG 생성. UDZO = zlib-compressed.
hdiutil create \
  -volname "CusTerminal ${TAG}" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING"
echo "   $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

# 3. GitHub Release 생성.
echo "→ 3/3  GitHub Release 생성"
NOTES_FILE="$(mktemp)"
cat > "$NOTES_FILE" <<EOF
## CusTerminal ${TAG}

**Cus**tom Ter**minal**. The name says it all. / 터미널을 내 취향에 맞게 커스텀. 이름부터가 그렇다.

---

### 🇺🇸 English

#### Download & Install
1. Download \`CusTerminal-${TAG}.dmg\` below
2. Open the DMG → drag \`CusTerminal.app\` into the \`Applications\` folder
3. **First launch**: right-click the app → **Open** (unsigned app, only the first time)

If macOS says the app is "damaged":
\`\`\`bash
xattr -dr com.apple.quarantine /Applications/CusTerminal.app
\`\`\`

#### Requirements
- macOS 14+

#### Features in this build
- Split panes (horizontal/vertical/custom, evenly distributed)
- Drag panes to top/bottom/left/right (freely mix rows and columns)
- Resize by dragging the divider
- Detach a pane into a new window (PTY session preserved)
- Rename each pane (double-click label, reflected in detached window title)
- Save frequently-used commands in the sidebar, drag onto a pane to run
- Resize or fully hide the sidebar (⌘B)
- Right-click inside the terminal → Copy / Paste / Select All

---

### 🇰🇷 한국어

#### 다운로드 & 설치
1. 아래 \`CusTerminal-${TAG}.dmg\` 다운로드
2. DMG 더블클릭 → 열리는 창에서 \`CusTerminal.app\` 을 \`Applications\` 폴더로 드래그
3. **처음 실행 시**: Launchpad 나 Finder 에서 앱 우클릭 → **열기** (서명 안 된 앱이라 첫 실행만 이렇게)

앱이 "손상되어 열 수 없습니다" 로 뜨면:
\`\`\`bash
xattr -dr com.apple.quarantine /Applications/CusTerminal.app
\`\`\`

#### 요구사항
- macOS 14 이상

#### 이번 버전 특징
- pane 분할 (가로/세로/개별 지정, 균등 배치)
- pane 드래그로 상/하/좌/우 재배치 (세로 ↔ 가로 자유 전환)
- pane 사이 divider 리사이즈
- pane 을 새 창으로 분리 (PTY 유지)
- pane 이름 라벨 (더블클릭 편집, 새 창 타이틀 반영)
- 왼쪽 사이드바에 자주 쓰는 커맨드 저장 → 카드를 pane 에 드래그해 실행
- 사이드바 폭 조절 / 완전 숨김 (⌘B)
- 터미널 우클릭 → 복사 / 붙여넣기 / 모두 선택
EOF

gh release create "$TAG" "$DMG_PATH" \
  --title "CusTerminal ${TAG}" \
  --notes-file "$NOTES_FILE" \
  $DRAFT_FLAG

rm -f "$NOTES_FILE"

echo ""
echo "✅ 릴리즈 완료!"
echo "→ gh release view $TAG --web  으로 브라우저에서 확인"
