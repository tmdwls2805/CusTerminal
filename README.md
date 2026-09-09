<p align="center">
  <img src="docs/logo.png" alt="CusTerminal" width="160" />
</p>

<h1 align="center">CusTerminal</h1>

<p align="center"><b>Cus</b>tom Ter<b>minal</b>. 이름부터가 그렇다.</p>

터미널을 매일 쓰면서 계속 마주치던 자잘한 불편함들을 하나씩 내 취향에 맞게 커스텀한 도구.
`layout` 셸 함수 (iTerm 자동 분할) 와 자체 미니 터미널 앱 `CusTerminal` 두 가지로 구성.

## 뭐가 불편했나 → 어떻게 바꿨나

**1. 매번 창을 4x3 이렇게 손으로 나누는 게 귀찮았다**
→ `layout 4 3` 한 줄로 원하는 분할 자동 생성. GUI 다이얼로그도 있어서 마우스로도 됨.

**2. 자주 쓰는 긴 커맨드를 매번 치거나 위쪽 화살표로 뒤지는 게 싫었다**
→ CusTerminal 왼쪽 사이드바에 커맨드 카드로 저장. **카드를 pane 에 드래그 & 드롭 → 즉시 실행**.
   외울 필요 없고, 어느 pane 에서든 재사용 가능.

**3. 딱 "분할 + 저장 커맨드" 만 있는 가벼운 터미널이 있으면 좋겠다**
→ SwiftUI + SwiftTerm 으로 미니 터미널 앱 `CusTerminal` 을 만듦. 익숙한 터미널을 계속 써도 되고, CusTerminal 을 함께 써도 됨.

**4. 분할 만들어 놓고 나서 "이 pane 만 옆으로 옮기고 싶은데" 를 하고 싶었다**
→ CusTerminal 은 각 pane 헤더의 햄버거를 잡고 다른 pane 의 **상/하/좌/우** 로 드래그하면 그 방향으로 재배치. IntelliJ 스타일 미리보기 하이라이트로 어디 들어갈지 시각화.

**5. 세로로 만들었다가 가로로 바꿀 수 있으면 편하다**
→ 위 드래그가 열↔행 사이 자유 이동을 지원. 원래 열이 비면 자동 제거.

**6. pane 크기가 고정되지 않고 자유롭게 바뀌면 좋겠다**
→ pane 사이 구분선을 잡고 드래그해서 자유 리사이즈.

**7. 작업하다 "이 창만 따로 뜯어 다른 모니터에 두고 싶다"**
→ pane 헤더의 "새 창으로 분리" 버튼. **PTY 세션 유지된 채** 새 창으로 옮겨짐.
   원래 창의 마지막 pane 이었으면 자리에 새 pane 이 자동 생성되어 창이 비지 않음.
   새 창에도 같은 커맨드 사이드바 공유.

**8. 새 pane 열 때마다 항상 홈에서 시작하면 좋겠다**
→ 새 pane 은 시작 직후 `cd ~ && clear` 를 자동 실행. `.zshrc` 가 어디로 cd 걸든 상관없이 홈에서 깔끔하게 시작.

**9. 어느 pane 이 뭐 하는 창인지 나중에 헷갈린다**
→ pane 헤더의 이름 라벨 더블클릭 → 인라인 편집. 이동/새 창 분리해도 이름 유지. 새 창 타이틀바에도 이름 반영.

## 구성

- **`layout` 셸 함수** — iTerm2 를 자동 분할. `CUSTERMINAL_APP` 환경변수 지정 시 CusTerminal 실행.
- **`CusTerminal`** — SwiftUI 자체 터미널 앱. 커맨드 저장, pane 드래그 재배치, 새 창 분리 등 위 기능 전부 포함.

## 다운로드 & 처음 사용하기

### A. 그냥 앱만 쓰고 싶다 (빌드 없이)
GitHub 저장소의 [Releases](../../releases) 페이지에서 최신 `CusTerminal-vX.Y.Z.zip` 다운로드
→ 압축 풀기 → `CusTerminal.app` 을 `/Applications` 로 이동 → **첫 실행은 우클릭 → 열기** (macOS 서명 안 된 앱이라 한 번만).

### B. 소스에서 직접 빌드

**1) 소스 받기**
```bash
git clone https://github.com/tmdwls2805/CusTerminal.git
cd CusTerminal
```

**2) `layout` 셸 함수 설치 (iTerm 자동 분할용)**
```bash
./install.sh
source ~/.zshrc
```
`~/.zshrc` 에 `source .../layout.sh` 한 줄이 추가되어 어디서든 `layout` 을 부를 수 있게 됨.
기본 동작은 iTerm2 를 자동 분할. CusTerminal 을 함께 쓰고 싶으면 아래 3번 진행.

**3) CusTerminal 자체 앱 빌드**
```bash
cd CusTerminal
./bundle.sh                                            # .app 번들 생성 (macOS 14+, Swift 5.9+ 필요)
```
빌드 결과: `CusTerminal/.build/release/CusTerminal.app`

**A. `layout` 함수와 연동해서 쓰기**
```bash
# 아래 한 줄을 ~/.zshrc 에 추가하면 영구 적용:
export CUSTERMINAL_APP="$HOME/Desktop/everyoung-code/CusTerminal/CusTerminal/.build/release/CusTerminal.app"

layout 4 3      # CusTerminal 창으로 열림
```

`CUSTERMINAL_APP` 설정 여부에 따라 `layout` 이 iTerm 또는 CusTerminal 을 띄움.

**B. CusTerminal 을 그냥 앱처럼 열기**
```bash
open CusTerminal/.build/release/CusTerminal.app
```
또는 `.app` 을 `/Applications` 로 옮겨서 Spotlight/Launchpad 로 실행.

### 처음 실행하면 뜨는 것
- **iTerm (`layout` 만 쓰는 경우)**: 인자 없이 실행하면 "왼쪽/오른쪽 세로 분할 수" 다이얼로그.
- **CusTerminal**: "오늘은 어떻게 꾸며볼까?" 시트. 가로 × 세로 pane 개수를 stepper 로 지정. 개별 지정 모드로 불균형 배치도 가능. "하나만 생성" 버튼으로 단일 창.

### 요구사항
- **`layout` (iTerm 모드)**: macOS + iTerm2 (환경설정에서 AppleScript 또는 Python API 허용)
- **CusTerminal**: macOS 14+ / Swift 5.9+ (Xcode 15 권장)

## 사용법 1: `layout` 셸 함수 (iTerm)

### GUI 모드
```bash
layout
```
"왼쪽 열 세로 / 오른쪽 열 세로" 두 입력창 → 값 넣고 생성.

### CLI 모드
```bash
layout 4 3          # 왼쪽 4행, 오른쪽 3행 (새 창)
layout 3 3
layout 2 2
```

첫 인자 = 왼쪽 열의 세로 pane 수, 둘째 = 오른쪽 열의 세로 pane 수.

## 사용법 2: CusTerminal (자체 터미널 앱)

```bash
cd CusTerminal
./bundle.sh                                                            # .app 번들 생성
export CUSTERMINAL_APP="$(pwd)/.build/release/CusTerminal.app"         # ~/.zshrc 에 추가하면 영구 적용
layout 4 3                                                             # CusTerminal 창으로 열림
```

자세한 기능(레이아웃 시트, 커맨드 저장, pane 드래그, 새 창 분리, 이름 라벨)은
[`CusTerminal/README.md`](./CusTerminal/README.md) 참고.

### 자주 쓰는 명령 저장 (요약)

CusTerminal 왼쪽 사이드바에 커맨드를 저장 → 카드를 pane 으로 드래그해 즉시 실행.
저장 파일: `CusTerminal/commands.json` (사용자별 로컬, `.gitignore` 처리).

## 릴리즈 만들기 (관리자용)

```bash
./release.sh v0.1.0          # 정식 릴리즈
./release.sh v0.1.0 --draft  # draft 로 먼저 확인
```

빌드 → `.app` → zip → GitHub Release 생성 + zip 첨부까지 자동. `gh` CLI 필요.

## 앞으로 추가할 것들 (Roadmap)

- [ ] **터미널 글자 색 / 테마**: 다크/라이트, 폰트 크기, ANSI 팔레트를 설정 시트에서 변경. Solarized · Dracula 등 프리셋 내장.
- [ ] **명령어 히스토리 시간순 검색**: 실행한 명령을 시간 스탬프와 함께 검색 (`⌘R`). 커맨드 저장소랑 연동해서 자주 쓰는 건 카드로 승격.
- [ ] **스크롤백 검색**: 터미널 안 텍스트 검색 (`⌘F`) → 하이라이트 + 위치 점프.
- [ ] **꾸미기 (고양이 등)**: 사이드바 하단 마스코트, 배경 이미지/투명도, pane 헤더 커스텀 아이콘 등 소소한 재미.

각 항목은 별도 이슈로 관리 예정. 원하는 기능이 더 있으면 이슈로 남겨주세요.
