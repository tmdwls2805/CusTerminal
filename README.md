# iterm-layout / MyTerm

터미널을 매일 쓰면서 계속 마주치던 자잘한 불편함들을 하나씩 없애기 위해 만든 도구.
`layout` 셸 함수 (iTerm 자동 분할) 와 자체 미니 터미널 앱 `MyTerm` 두 가지로 구성.

## 뭐가 불편했나 → 어떻게 바꿨나

**1. 매번 창을 4x3 이렇게 손으로 나누는 게 귀찮았다**
→ `layout 4 3` 한 줄로 원하는 분할 자동 생성. GUI 다이얼로그도 있어서 마우스로도 됨.

**2. 자주 쓰는 긴 커맨드를 매번 치거나 위쪽 화살표로 뒤지는 게 싫었다**
→ MyTerm 왼쪽 사이드바에 커맨드 카드로 저장. **카드를 pane 에 드래그 & 드롭 → 즉시 실행**.
   외울 필요 없고, 어느 pane 에서든 재사용 가능.

**3. iTerm 은 무겁고 기능이 많은데, 나는 딱 "분할 + 저장 커맨드" 만 필요했다**
→ SwiftUI + SwiftTerm 으로 미니 터미널 앱 `MyTerm` 을 만들어 대안 제공. 원하면 iTerm 그대로 써도 됨.

**4. 분할 만들어 놓고 나서 "이 pane 만 옆으로 옮기고 싶은데" 가 안 됐다**
→ MyTerm 은 각 pane 헤더의 햄버거를 잡고 다른 pane 의 **상/하/좌/우** 로 드래그하면 그 방향으로 재배치. IntelliJ 스타일 미리보기 하이라이트로 어디 들어갈지 시각화.

**5. 세로로 만들었다가 가로로 바꾸는 게 iTerm 에선 안 됐다**
→ 위 드래그가 열↔행 사이 자유 이동을 지원. 원래 열이 비면 자동 제거.

**6. pane 크기가 고정되는 게 답답했다**
→ pane 사이 구분선을 잡고 드래그해서 자유 리사이즈.

**7. 작업하다 "이 창만 따로 뜯어 다른 모니터에 두고 싶다" 가 안 됐다**
→ pane 헤더의 "새 창으로 분리" 버튼. **PTY 세션 유지된 채** 새 창으로 옮겨짐.
   원래 창의 마지막 pane 이었으면 자리에 새 pane 이 자동 생성되어 창이 비지 않음.
   새 창에도 같은 커맨드 사이드바 공유.

**8. 새 pane 열 때마다 `.zshrc` 가 어디로 cd 걸어 놔서 항상 홈부터 시작하고 싶었다**
→ 새 pane 은 시작 직후 `cd ~ && clear` 를 자동 실행. 항상 홈 디렉터리에서 깔끔하게 시작.

## 구성

- **`layout` 셸 함수** — iTerm2 를 자동 분할. `MYTERM_APP` 환경변수 지정 시 MyTerm 실행.
- **`MyTerm`** (옵션) — SwiftUI 자체 터미널 앱. 커맨드 저장, pane 드래그 재배치, 새 창 분리 등 모든 기능 포함.

## 다운로드 & 처음 사용하기

### 1) 소스 받기
```bash
git clone https://github.com/tmdwls2805/iterm-layout.git
cd iterm-layout
```

### 2) `layout` 셸 함수 설치 (iTerm 자동 분할용)
```bash
./install.sh
source ~/.zshrc
```
`~/.zshrc` 에 `source .../layout.sh` 한 줄이 추가되어 어디서든 `layout` 을 부를 수 있게 됨.

### 3) (선택) MyTerm 자체 앱 빌드
iTerm 대신 자체 미니 터미널 앱을 쓰고 싶으면:

```bash
cd MyTerm
./bundle.sh                                            # .app 번들 생성 (macOS 13+, Swift 5.9+ 필요)
```

빌드 결과: `MyTerm/.build/release/MyTerm.app`

**A. `layout` 함수와 연동해서 쓰기**
```bash
# 아래 한 줄을 ~/.zshrc 에 추가하면 영구 적용:
export MYTERM_APP="$HOME/Desktop/everyoung-code/iterm-layout/MyTerm/.build/release/MyTerm.app"

layout 4 3      # 이제 iTerm 대신 MyTerm 창으로 열림
```

`MYTERM_APP` 이 설정되어 있지 않으면 `layout` 은 기존대로 iTerm 을 사용.

**B. MyTerm 을 그냥 앱처럼 열기**
```bash
open MyTerm/.build/release/MyTerm.app
```
또는 `MyTerm.app` 을 `/Applications` 로 옮겨서 Spotlight/Launchpad 로 실행.

### 4) 처음 실행하면 뜨는 것
- **iTerm (`layout` 만 쓰는 경우)**: 인자 없이 실행하면 "왼쪽/오른쪽 세로 분할 수" 다이얼로그.
- **MyTerm**: 가로(열 수) × 세로(pane 수) 를 stepper 로 지정하는 시트. 개별 지정 모드로 불균형 배치도 가능. "하나만 생성" 버튼으로 단일 창.

### 요구사항 요약
- `layout` (iTerm 모드): macOS + iTerm2 (환경설정에서 AppleScript 또는 Python API 허용)
- `MyTerm`: macOS 13+ / Swift 5.9+ (Xcode 15 권장)

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

### 요구사항
- macOS + iTerm2
- iTerm 환경설정 → General → Magic → "Enable Python API" 또는 AppleScript 허용

## 사용법 2: MyTerm (자체 터미널 앱)

```bash
cd MyTerm
./bundle.sh                                                       # .app 번들 생성
export MYTERM_APP="$(pwd)/.build/release/MyTerm.app"              # ~/.zshrc 에 추가하면 영구 적용
layout 4 3                                                        # MyTerm 창으로 열림
```

`MYTERM_APP` 이 설정되어 있으면 `layout` 이 iTerm 대신 MyTerm 을 띄움.
설정 안 하면 기존대로 iTerm 사용.

자세한 기능(레이아웃 시트, 커맨드 저장, pane 드래그, 새 창 분리)은
[`MyTerm/README.md`](./MyTerm/README.md) 참고.

### 자주 쓰는 명령 저장 (요약)

MyTerm 왼쪽 사이드바에 커맨드를 저장 → 카드를 pane 으로 드래그해 즉시 실행.
저장 파일: `MyTerm/commands.json` (사용자별 로컬, `.gitignore` 처리).

## 앞으로 추가할 것들 (Roadmap)

터미널 쓰다 아직 남아있는 불편함들. 우선순위 순.

- [ ] **pane 이름 변경**: 각 pane 에 라벨 붙이기 (예: "backend", "docker logs"). 헤더에 표시 + 새 창 분리 시 그 이름이 창 타이틀로.
- [ ] **터미널 글자 색 / 테마 초기화**: 다크/라이트, 폰트 크기, ANSI 팔레트를 설정 시트에서 변경. 프리셋 몇 개 (Solarized, Dracula 등) 내장.
- [ ] **명령어 히스토리 시간순 검색**: 지금까지 실행한 명령을 시간 스탬프와 함께 검색 (`⌘R` 같은 단축키). 커맨드 저장소랑 연동해서 자주 쓰는 건 카드로 승격 가능.
- [ ] **터미널 안 보일 때 검색해서 스크롤**: 스크롤백에서 텍스트 검색 (`⌘F`) → 하이라이트 + 해당 위치로 점프.
- [ ] **꾸미기 (고양이 등)**: 사이드바 하단 마스코트, 배경 이미지/투명도, pane 헤더 커스텀 아이콘 등 소소한 재미 요소.

각 항목은 별도 이슈로 관리 예정. 원하는 기능이 더 있으면 이슈로 남겨주세요.
