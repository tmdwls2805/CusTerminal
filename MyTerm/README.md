# MyTerm

SwiftUI + [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 으로 만든 미니 터미널 앱.
"터미널 쓰다 이거 좀 불편했는데" 싶은 부분들을 하나씩 해결하는 게 목표.

## 이 앱이 해결하는 것들

- **레이아웃**: 열 개수와 각 열의 pane 수를 시작 시 다이얼로그에서 stepper 로 지정. 균등/개별 모드 지원.
- **드래그 재배치**: pane 헤더 햄버거 잡고 다른 pane 의 **상/하/좌/우** 로 드롭 → 그 방향으로 이동. 세로↔가로 자유 전환.
- **드롭 미리보기**: IntelliJ 스타일로 들어갈 절반 영역이 반투명 파란색으로 미리 보임.
- **리사이즈**: pane 사이 divider 잡고 드래그.
- **새 창 분리**: pane 을 새 창(NSWindow) 으로 뜯어냄. PTY 세션 유지. 마지막 pane 이면 자리에 새 pane 자동 생성.
- **커맨드 저장/실행**: 왼쪽 사이드바에 커맨드 저장, pane 으로 드래그 & 드롭 → 즉시 실행. 새 창과도 저장소 공유.
- **홈에서 시작**: 새 pane 은 `.zshrc` 가 어디로 cd 걸든 상관없이 항상 `~` 에서 시작 (`cd ~ && clear` 자동 실행).

## 요구사항

- macOS 13+ / Swift 5.9+ (Xcode 15 권장)

## 빌드 & 실행

가장 간단한 방법:
```bash
cd MyTerm
./bundle.sh
open .build/release/MyTerm.app
```

`swift run` 으로도 실행 가능:
```bash
swift run -c release                       # 시작 시 레이아웃 다이얼로그
swift run -c release -- --layout 4,3       # 왼쪽 4행 + 오른쪽 3행 (다이얼로그 스킵)
swift run -c release -- --layout 3,3,2     # 3열
```

`--layout` 인자를 주면 다이얼로그 없이 바로 해당 레이아웃으로 열림.

## 사용법

### 레이아웃 다이얼로그

앱 실행 시 뜨는 시트에서:

- **균등 모드**: 가로(열 수) × 세로(각 열 pane 수) 를 stepper 로 지정. 모든 열이 같은 pane 수.
- **개별 지정 모드**: 열 개수를 조절하고, 각 열의 pane 수를 따로 지정. 불균형 배치 가능 (예: `[3, 1, 2]`).
- **하나만 생성**: stepper 무시하고 단일 pane 창.
- 미리보기 그리드가 실시간으로 반영됨.

### pane 조작

각 pane 헤더 오른쪽 버튼:

| 버튼 | 동작 |
|------|------|
| `+ ▤` | 같은 열 아래에 새 pane 추가 (세로 분할) |
| `+ ▥` | 오른쪽에 새 열 생성 (가로 분할) |
| `⇥` | 이 pane 을 새 창으로 분리 (PTY 유지) |
| `×` | 이 pane 닫기 (열 비면 열도 제거) |

헤더 왼쪽 **햄버거(≡)** 를 잡고 다른 pane 위로 드래그:

- 대상 pane 의 **위 절반** → 그 pane 위에 삽입 (세로 정렬)
- **아래 절반** → 그 pane 아래에 삽입 (세로 정렬)
- **왼쪽 절반** → 그 pane 왼쪽에 새 열 (가로 정렬)
- **오른쪽 절반** → 그 pane 오른쪽에 새 열 (가로 정렬)

원본 pane 이 있던 열이 비면 자동 제거되어 열↔행 자유 전환됨.

### 커맨드 저장 / 불러오기

MyTerm 창 **왼쪽 사이드바** = 커맨드 저장소.

- **저장**: 사이드바 입력창에 명령 입력 → `Enter` 또는 `저장` 버튼
- **실행**: 저장된 카드를 원하는 터미널 pane 위로 **드래그 & 드롭** → 그 pane 에서 실행
- **삭제**: 카드 오른쪽 `×` 버튼
- **새 창과 공유**: pane 을 새 창으로 분리해도 같은 커맨드 목록이 그 창에도 보임

저장 파일:
```
MyTerm/commands.json   (프로젝트 폴더 안)
```

JSON 배열 (`[{"id": "...", "text": "..."}]`) 형식. 앱 재실행 후에도 유지.
`.gitignore` 에 등록되어 사용자별 로컬 저장 (다른 사람 커맨드가 git 으로 섞이지 않음).

## 앞으로 추가할 것들

- [ ] pane 이름 변경 (헤더에 라벨, 새 창 분리 시 창 타이틀로)
- [ ] 글자 색 / 테마 / 폰트 설정 시트 (Solarized, Dracula 프리셋)
- [ ] 명령 히스토리 시간순 검색 (⌘R) + 카드로 승격
- [ ] 스크롤백 텍스트 검색 (⌘F) + 하이라이트 점프
- [ ] 꾸미기 요소 (마스코트, 배경 이미지/투명도)

## 파일 구조

- `Package.swift` — SwiftTerm 의존성
- `bundle.sh` — `swift build` 결과를 `.app` 번들로 감싸는 스크립트
- `Sources/MyTerm/`
  - `MyTermApp.swift` — 앱 진입점
  - `ContentView.swift` — 메인 창 (사이드바 + pane 컨테이너 + 레이아웃 시트)
  - `LayoutStore.swift` — pane 트리 상태 + 조작 API (add/remove/move/detach)
  - `SplitContainer.swift` — `NSSplitView` 래퍼 (리사이즈 가능한 분할)
  - `TerminalPane.swift` — SwiftTerm PTY 어댑터, 새 pane 홈 디렉터리 시작
  - `DragBridge.swift` — AppKit 드래그/드롭 브릿지 (햄버거 소스, 4방향 드롭 오버레이)
  - `DetachedWindow.swift` — pane 을 새 창으로 분리
  - `Command.swift` / `CommandListView.swift` — 저장 커맨드 모델 + 사이드바 UI
