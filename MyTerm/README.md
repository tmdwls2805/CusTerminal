# MyTerm

SwiftUI + [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 으로 만든 미니 터미널 앱.
`layout` 스크립트에서 호출해 원하는 분할(예: 4,3)로 자체 창을 띄우는 것이 목적.

## 요구사항

- macOS 13+ / Swift 5.9+ (Xcode 15 권장)

## 빌드 & 실행

```bash
cd MyTerm
swift run -c release             # 기본 1x1
swift run -c release -- --layout 4,3   # 왼쪽 4행, 오른쪽 3행
swift run -c release -- --layout 3,3,2 # 3열: 3행 / 3행 / 2행
```

## 구조

- `Package.swift` — SwiftTerm 의존성
- `Sources/MyTerm/MyTermApp.swift` — 앱 진입점
- `Sources/MyTerm/ContentView.swift` — 컬럼×행 그리드
- `Sources/MyTerm/TerminalPane.swift` — SwiftTerm 어댑터 (PTY + zsh)
- `Sources/MyTerm/Command.swift` — 저장 커맨드 모델 + JSON 영속화
- `Sources/MyTerm/CommandListView.swift` — 왼쪽 사이드바(입력·카드·드래그)

## 자주 쓰는 명령 저장 / 불러오기

MyTerm 창 **왼쪽 사이드바**가 커맨드 저장소.

- **저장**: 사이드바 입력창에 명령 입력 → `Enter` 또는 `저장` 버튼
- **실행**: 저장된 카드를 원하는 터미널 pane 위로 **드래그 & 드롭** → 그 pane 에서 실행
- **삭제**: 카드 오른쪽 `×` 버튼

### 저장 파일 위치

```
MyTerm/commands.json   (프로젝트 폴더 안)
```

JSON 배열(`[{"id": "...", "text": "..."}]`) 형식. 앱 재실행 후에도 유지되고,
파일을 직접 편집하거나 다른 맥에 복사해 그대로 불러올 수 있음.

이 파일은 사용자별 로컬 저장소로 취급하기 위해 `.gitignore` 에 등록되어 있음
(다른 사람 커맨드가 git 으로 섞이는 것 방지). 처음 실행 시 파일이 없으면
자동으로 빈 상태에서 시작됨.
