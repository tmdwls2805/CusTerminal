import SwiftUI
import AppKit

struct ContentView: View {
  @State private var store = CommandStore()
  @State private var themeStore = ThemeStore()
  @State private var customThemeStore = CustomThemeStore()
  @State private var fontStore = FontStore()
  @State private var backgroundStore = BackgroundStore()
  @State private var separatorStore = SeparatorStore()
  @State private var dropRunStore = DropRunStore()
  @StateObject private var layout = LayoutStore()
  @State private var showLayoutPrompt: Bool = false
  @State private var sidebarVisible: Bool = true
  @State private var sidebarWidth: CGFloat = 260

  var body: some View {
    SidebarSplit(
      sidebarVisible: $sidebarVisible,
      sidebarWidth: $sidebarWidth,
      sidebar: { CommandListView(store: store) },
      content: {
        VStack(spacing: 0) {
          // 상단에 사이드바 토글 얇은 바.
          HStack(spacing: 4) {
            SidebarToggleButton(visible: $sidebarVisible)
            Spacer()
          }
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
          LayoutContainer(layout: layout)
            .background(Color.black)
        }
      }
    )
    .environment(themeStore)
    .environment(customThemeStore)
    .environment(fontStore)
    .environment(backgroundStore)
    .environment(separatorStore)
    .environment(dropRunStore)
    .environment(\.currentLayoutStore, layout)
    .onAppear {
      themeStore.customStore = customThemeStore
      DetachedWindowController.sharedStore = store
      DetachedWindowController.sharedThemeStore = themeStore
      DetachedWindowController.sharedCustomStore = customThemeStore
      DetachedWindowController.sharedFontStore = fontStore
      DetachedWindowController.sharedBackgroundStore = backgroundStore
      DetachedWindowController.sharedSeparatorStore = separatorStore
      DetachedWindowController.sharedDropRunStore = dropRunStore
      let args = CommandLine.arguments
      if let idx = args.firstIndex(of: "--layout"), idx + 1 < args.count {
        applyLayout(spec: args[idx + 1])
      } else {
        showLayoutPrompt = true
      }
    }
    .sheet(isPresented: $showLayoutPrompt) {
      LayoutPromptSheet { columnSizes in
        applyLayout(columnSizes: columnSizes)
        showLayoutPrompt = false
      }
    }
  }

  private func applyLayout(spec: String) {
    let parts = spec.split(separator: ",").compactMap { Int($0) }
    applyLayout(columnSizes: parts.isEmpty ? [1] : parts)
  }

  private func applyLayout(columnSizes: [Int]) {
    layout.columns = columnSizes.map { count in
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
        session: session,
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
  @ObservedObject var session: TerminalSession
  @Environment(ThemeStore.self) private var themeStore
  @Environment(FontStore.self) private var fontStore
  @Environment(BackgroundStore.self) private var backgroundStore
  let onClose: () -> Void
  let onSplitVertical: () -> Void
  let onSplitHorizontal: () -> Void
  let onDetach: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      PaneDragHandle(sessionID: session.id)
        .frame(width: 22, height: 18)
        .tooltip("드래그해서 다른 pane 의 상/하/좌/우 로 이동")
      PaneNameLabel(session: session)
      Spacer()
      if themeStore.mode == .perPane {
        SessionThemeButton(session: session)
      }
      if fontStore.mode == .perPane {
        SessionFontButton(session: session)
      }
      if backgroundStore.mode == .perPane {
        SessionBackgroundButton(session: session)
      }
      PaneHistoryButton(session: session)
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

/// pane 이름 라벨. 더블클릭하면 인라인 편집 가능. Enter 저장, Esc 취소.
private struct PaneNameLabel: View {
  @ObservedObject var session: TerminalSession
  @State private var isEditing: Bool = false
  @State private var draft: String = ""
  @FocusState private var focused: Bool

  var body: some View {
    Group {
      if isEditing {
        TextField("이름", text: $draft)
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 11))
          .frame(maxWidth: 160)
          .focused($focused)
          .onSubmit { commit() }
          .onExitCommand { cancel() }
          .onAppear { focused = true }
          .tooltip("Enter 저장 · Esc 취소")
      } else {
        Text(session.name.isEmpty ? "이름 없음" : session.name)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(session.name.isEmpty ? .tertiary : .primary)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: 160, alignment: .leading)
          .contentShape(Rectangle())
          .tooltip("더블클릭해서 pane 이름 편집 (이 pane 을 뭐하는 창인지 표시)")
          .onTapGesture(count: 2) {
            draft = session.name
            isEditing = true
          }
      }
    }
  }

  private func commit() {
    session.name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    isEditing = false
  }
  private func cancel() {
    isEditing = false
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
    .tooltip(help)
  }
}

/// 앱 시작 시 뜨는 레이아웃 입력 시트.
/// - 균등 모드: 가로/세로 각각 stepper 로 지정 → 모든 열이 같은 pane 수
/// - 개별 모드: 각 열마다 세로 pane 수를 따로 지정 (불균형 배치)
struct LayoutPromptSheet: View {
  /// 최종 레이아웃을 [열별 pane 수] 배열로 넘겨줌.
  let onSubmit: ([Int]) -> Void

  @State private var mode: Mode = .uniform
  @State private var horizontalCount: Int = 1
  @State private var verticalCount: Int = 1
  /// 개별 모드에서 각 열의 pane 수. mode 전환 시 uniform 값으로 초기화됨.
  @State private var perColumn: [Int] = [1]

  enum Mode: String, CaseIterable, Identifiable {
    case uniform = "균등"
    case custom = "개별 지정"
    var id: String { rawValue }
  }

  private var columnSizes: [Int] {
    switch mode {
    case .uniform: return Array(repeating: verticalCount, count: horizontalCount)
    case .custom: return perColumn
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("CusTerminal — 오늘은 어떻게 꾸며볼까?")
        .font(.headline)

      Picker("", selection: $mode) {
        ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      Group {
        switch mode {
        case .uniform: uniformControls
        case .custom: customControls
        }
      }

      LayoutPreview(columnSizes: columnSizes)
        .frame(height: 100)

      Text("총 \(columnSizes.reduce(0, +)) 개 pane · \(columnSizes.count) 열")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack {
        Button("하나만 생성") { onSubmit([1]) }
        Spacer()
        Button("생성") { onSubmit(columnSizes) }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 420)
    .onChange(of: mode) { _, new in
      // 균등 → 개별 전환 시 현재 균등 값으로 열별 배열 채움.
      if new == .custom {
        perColumn = Array(repeating: verticalCount, count: horizontalCount)
      } else {
        // 개별 → 균등 전환 시 열 수만 유지.
        horizontalCount = max(1, perColumn.count)
      }
    }
  }

  private var uniformControls: some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
      GridRow {
        Text("가로 (열 수)")
        Stepper(value: $horizontalCount, in: 1...10) {
          Text("\(horizontalCount)").frame(minWidth: 24, alignment: .trailing).monospacedDigit()
        }
      }
      GridRow {
        Text("세로 (각 열 pane 수)")
        Stepper(value: $verticalCount, in: 1...10) {
          Text("\(verticalCount)").frame(minWidth: 24, alignment: .trailing).monospacedDigit()
        }
      }
    }
  }

  private var customControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("열 개수: \(perColumn.count)")
          .font(.subheadline)
        Spacer()
        Button {
          if perColumn.count > 1 { perColumn.removeLast() }
        } label: {
          Image(systemName: "minus")
        }
        .disabled(perColumn.count <= 1)
        Button {
          if perColumn.count < 10 { perColumn.append(1) }
        } label: {
          Image(systemName: "plus")
        }
        .disabled(perColumn.count >= 10)
      }

      // 각 열별 stepper 목록.
      ScrollView {
        VStack(spacing: 6) {
          ForEach(perColumn.indices, id: \.self) { i in
            HStack {
              Text("열 \(i + 1)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 46, alignment: .leading)
              Stepper(value: Binding(
                get: { perColumn[i] },
                set: { perColumn[i] = $0 }
              ), in: 1...10) {
                Text("세로 \(perColumn[i]) 개")
                  .monospacedDigit()
              }
            }
          }
        }
      }
      .frame(maxHeight: 130)
    }
  }
}

/// [열별 pane 수] 배열을 작은 사각형 그리드로 시각화 (불균형 지원).
private struct LayoutPreview: View {
  let columnSizes: [Int]

  var body: some View {
    GeometryReader { geo in
      let gap: CGFloat = 3
      let cols = max(1, columnSizes.count)
      let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
      HStack(spacing: gap) {
        ForEach(columnSizes.indices, id: \.self) { i in
          let n = max(1, columnSizes[i])
          let cellH = (geo.size.height - gap * CGFloat(n - 1)) / CGFloat(n)
          VStack(spacing: gap) {
            ForEach(0..<n, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor.opacity(0.7), lineWidth: 1))
                .frame(width: cellW, height: cellH)
            }
          }
        }
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
    }
  }
}
