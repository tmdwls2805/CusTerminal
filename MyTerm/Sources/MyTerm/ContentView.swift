import SwiftUI
import AppKit

struct ContentView: View {
  @State private var store = CommandStore()
  @StateObject private var layout = LayoutStore()
  @State private var showLayoutPrompt: Bool = false
  @State private var layoutInput: String = "1"

  var body: some View {
    HStack(spacing: 0) {
      CommandListView(store: store)
        .frame(width: 260)

      Divider()

      LayoutContainer(layout: layout)
        .background(Color.black)
    }
    .onAppear {
      // 새 창에서도 동일한 저장 커맨드 목록 공유.
      DetachedWindowController.sharedStore = store
      let args = CommandLine.arguments
      if let idx = args.firstIndex(of: "--layout"), idx + 1 < args.count {
        applyLayout(spec: args[idx + 1])
      } else {
        showLayoutPrompt = true
      }
    }
    .sheet(isPresented: $showLayoutPrompt) {
      LayoutPromptSheet(
        spec: $layoutInput,
        onSubmit: {
          applyLayout(spec: layoutInput)
          showLayoutPrompt = false
        }
      )
    }
  }

  private func applyLayout(spec: String) {
    let parts = spec.split(separator: ",").compactMap { Int($0) }
    let counts = parts.isEmpty ? [1] : parts
    layout.columns = counts.map { count in
      TerminalColumn(sessions: (0..<max(1, count)).map { _ in TerminalSession() })
    }
  }
}

/// 열 = 가로 방향 NSSplitView, 각 열 안 pane = 세로 방향 NSSplitView.
private struct LayoutContainer: View {
  @ObservedObject var layout: LayoutStore

  var body: some View {
    if layout.columns.isEmpty {
      Color.black
    } else {
      SplitContainer(
        isVertical: true,
        items: layout.columns.map { column in
          SplitItem(id: column.id, view: AnyView(ColumnView(layout: layout, column: column)))
        }
      )
    }
  }
}

private struct ColumnView: View {
  @ObservedObject var layout: LayoutStore
  @ObservedObject var column: TerminalColumn

  var body: some View {
    SplitContainer(
      isVertical: false,
      items: column.sessions.map { session in
        SplitItem(id: session.id, view: AnyView(PaneChrome(layout: layout, session: session)))
      }
    )
  }
}

/// pane 헤더(드래그/제거/분할/새창) + 실제 터미널 + 드롭 오버레이.
private struct PaneChrome: View {
  @ObservedObject var layout: LayoutStore
  @ObservedObject var session: TerminalSession

  var body: some View {
    VStack(spacing: 0) {
      PaneHeader(
        sessionID: session.id,
        onClose: { layout.remove(session.id) },
        onSplitVertical: { layout.splitVertical(after: session.id) },
        onSplitHorizontal: { layout.splitHorizontal(after: session.id) },
        onDetach: { detachToNewWindow() }
      )
      ZStack {
        TerminalPane(session: session)
        // 드래그 세션 중일 때만 hitTest 통과 → 평소엔 터미널이 정상 동작.
        PaneDropTarget(targetSessionID: session.id) { sourceID, edge in
          DispatchQueue.main.async {
            layout.move(source: sourceID, target: session.id, edge: edge)
          }
        }
      }
    }
  }

  private func detachToNewWindow() {
    let wasLast = layout.columns.count == 1 && layout.columns.first?.sessions.count == 1
    guard let detached = layout.detach(session.id) else { return }
    if wasLast {
      layout.columns = [TerminalColumn(sessions: [TerminalSession()])]
    }
    DetachedWindowController.open(session: detached)
  }
}

private struct PaneHeader: View {
  let sessionID: UUID
  let onClose: () -> Void
  let onSplitVertical: () -> Void
  let onSplitHorizontal: () -> Void
  let onDetach: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      PaneDragHandle(sessionID: sessionID)
        .frame(width: 22, height: 18)
        .help("드래그해서 다른 pane 의 상/하/좌/우 로 이동")
      Spacer()
      HeaderButton(system: "plus.rectangle.portrait", help: "세로 분할 (아래에 pane 추가)", action: onSplitVertical)
      HeaderButton(system: "plus.rectangle", help: "가로 분할 (오른쪽에 새 열)", action: onSplitHorizontal)
      HeaderButton(system: "rectangle.portrait.and.arrow.right", help: "새 창으로 분리", action: onDetach)
      HeaderButton(system: "xmark", help: "이 pane 닫기", action: onClose)
    }
    .font(.system(size: 11, weight: .medium))
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
  }
}

private struct HeaderButton: View {
  let system: String
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: system)
        .frame(width: 18, height: 16)
    }
    .buttonStyle(.borderless)
    .help(help)
  }
}

/// 앱 시작 시 뜨는 레이아웃 입력 시트.
/// - `1` = 창 하나 · `4` = 세로 4개 · `4,3` = 4행+3행 · `3,3,2` = 3열
struct LayoutPromptSheet: View {
  @Binding var spec: String
  let onSubmit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("MyTerm — 레이아웃")
        .font(.headline)

      VStack(alignment: .leading, spacing: 4) {
        Text("열마다 세로 분할 수를 콤마로 입력하세요.")
          .font(.subheadline)
        Text("예: 1 = 창 하나 · 4 = 세로 4개 · 4,3 = 4행+3행 · 3,3,2 = 3열")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        TextField("예: 1  또는  4,3", text: $spec)
          .textFieldStyle(.roundedBorder)
          .onSubmit(onSubmit)

        Menu("프리셋") {
          Button("창 하나 (1)") { spec = "1"; onSubmit() }
          Button("세로 2 (2)") { spec = "2"; onSubmit() }
          Button("가로 2 (1,1)") { spec = "1,1"; onSubmit() }
          Button("2 x 2 (2,2)") { spec = "2,2"; onSubmit() }
          Button("4 x 3 (4,3)") { spec = "4,3"; onSubmit() }
          Button("3 x 3 (3,3)") { spec = "3,3"; onSubmit() }
        }
        .fixedSize()
      }

      HStack {
        Spacer()
        Button("생성", action: onSubmit)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 420)
  }
}
