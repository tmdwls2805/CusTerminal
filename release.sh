#!/usr/bin/env bash
# GitHub Release 생성 자동화.
# 사용: ./release.sh v0.1.0 [--draft]
#
# 순서:
#   1. CusTerminal.app 빌드 (bundle.sh) → 아이콘 포함
#   2. .app 을 zip 으로 압축
#   3. gh release create 로 GitHub Release 생성 + zip 첨부
#
# 요구사항: gh CLI 설치 & 로그인 (gh auth login)

set -e

TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "사용: $0 <tag> [--draft]"
  echo "예:   $0 v0.1.0"
  echo "      $0 v0.1.0 --draft"
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
  echo "❌ 이미 '$TAG' 릴리즈가 존재합니다. 다른 태그를 쓰거나 gh release delete '$TAG' 후 재시도."
  exit 1
fi

# 1. 빌드.
echo "→ 1/3  CusTerminal.app 빌드"
cd CusTerminal
./bundle.sh
APP_PATH="$(pwd)/.build/release/CusTerminal.app"
cd "$ROOT"

# 2. zip 압축.
echo "→ 2/3  CusTerminal-${TAG}.zip 압축"
DIST="$ROOT/dist"
mkdir -p "$DIST"
ZIP_PATH="$DIST/CusTerminal-${TAG}.zip"
rm -f "$ZIP_PATH"

# ditto 로 압축: macOS 메타데이터(속성) 보존 + Finder 에서 이상 없이 풀림.
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
echo "   $ZIP_PATH"

# 3. GitHub Release 생성.
echo "→ 3/3  GitHub Release 생성"
NOTES_FILE="$(mktemp)"
cat > "$NOTES_FILE" <<EOF
## CusTerminal ${TAG}

터미널을 내 취향에 맞게 커스텀. 이름부터가 그렇다.

### 다운로드 & 설치
1. 아래 \`CusTerminal-${TAG}.zip\` 다운로드
2. 압축 풀기
3. \`CusTerminal.app\` 을 \`/Applications\` 으로 이동
4. **처음 실행 시**: 앱 우클릭 → \`열기\` (macOS 서명 안 된 앱이라 첫 실행만 이렇게)

### 요구사항
- macOS 14 이상

### 이번 버전 특징
- pane 분할 (가로/세로/개별 지정, 균등 배치)
- pane 드래그로 상/하/좌/우 재배치 (세로 ↔ 가로 자유 전환)
- pane 사이 divider 리사이즈
- pane 을 새 창으로 분리 (PTY 유지)
- pane 이름 라벨 (더블클릭 편집, 새 창 타이틀 반영)
- 왼쪽 사이드바에 자주 쓰는 커맨드 저장 → 카드를 pane 에 드래그해 실행
- 사이드바 폭 조절 / 완전 숨김 (⌘B)
EOF

gh release create "$TAG" "$ZIP_PATH" \
  --title "CusTerminal ${TAG}" \
  --notes-file "$NOTES_FILE" \
  $DRAFT_FLAG

rm -f "$NOTES_FILE"

echo ""
echo "✅ 릴리즈 완료!"
echo "→ gh release view $TAG --web  으로 브라우저에서 확인"
