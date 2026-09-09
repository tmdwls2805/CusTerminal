# iterm-layout

iTerm2 창을 원하는 열/행 조합으로 자동 분할.

## 목표

매일 사용하는 긴 커맨드를 매번 치기 귀찮을 때, 저장해두고
원하는 iTerm 창에서 톡톡 눌러 실행할 수 있게 한다.
긴 커맨드를 외워서 다시 치지 않도록 하는 것이 목적.

## 설치

```bash
git clone https://github.com/tmdwls2805/iterm-layout.git
cd iterm-layout
./install.sh
source ~/.zshrc
```

## 사용

### GUI 모드 (인자 없이)
```bash
layout
```
- "몇 대 몇으로 나눌까요?" 다이얼로그에 `4 3` 같이 입력
- "새 창" / "현재 창" 선택

### CLI 모드
```bash
layout 4 3          # 새 창에 왼쪽 4행 · 오른쪽 3행
layout 4 3 same     # 현재 창에서 그대로 분할
layout 3 3
layout 2 2
```

첫 인자 = 왼쪽 열 안 세션 수, 둘째 인자 = 오른쪽 열 안 세션 수,
셋째 인자(옵션) = `new`(기본) 또는 `same`.

## 요구사항

- macOS + iTerm2 (Preferences → General → Magic → **"Enable Python API"** or "AppleScript" 허용)

## MyTerm (자체 터미널 앱, 옵션)

iTerm 대신 자체 미니 터미널 앱으로 뜨게 하고 싶으면 [`MyTerm`](./MyTerm) 서브 프로젝트 빌드 후
`MYTERM_BIN` 환경변수를 지정하면 `layout` 이 그쪽을 실행함.

```bash
cd MyTerm
swift build -c release
export MYTERM_BIN="$(pwd)/.build/release/MyTerm"
layout 4 3   # MyTerm 창으로 4×3 분할 열림
```

`MYTERM_BIN` 이 없으면 기존대로 iTerm 사용.

### 자주 쓰는 명령 저장

MyTerm 창 왼쪽 사이드바에 명령을 저장해두고, 카드를 pane 으로 드래그 & 드롭해서 실행할 수 있음.
저장 파일: `MyTerm/commands.json` (프로젝트 폴더 안, `.gitignore` 처리되어 사용자별 로컬 저장).
자세한 내용은 [`MyTerm/README.md`](./MyTerm/README.md#자주-쓰는-명령-저장--불러오기) 참고.
