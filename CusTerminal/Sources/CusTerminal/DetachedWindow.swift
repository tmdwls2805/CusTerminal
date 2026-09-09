import SwiftUI
import AppKit

/// 새 창으로 분리된 pane 들을 관리. 각 창은 자체 LayoutStore 를 가진다.
enum DetachedWindowController {
  private static var controllers: [NSWindowController] = []

  /// 커맨드 스토어는 메인 창과 공유해야 새 창에서도 같은 카드 목록이 보인다.
  static var sharedStore: CommandStore?
  /// 테마 스토어도 공유 → 어느 창에서 바꿔도 즉시 반영.
  static var sharedThemeStore: ThemeStore?
  /// 커스텀 테마 저장소도 공유.
  static var sharedCustomStore: CustomThemeStore?
  /// 폰트 스토어도 공유.
  static var sharedFontStore: FontStore?
  /// 배경 스토어도 공유.
  static var sharedBackgroundStore: BackgroundStore?

  static func open(session: TerminalSession) {
    let layout = LayoutStore(columns: [TerminalColumn(sessions: [session])])
    let store = sharedStore ?? CommandStore()
    sharedStore = store
    let themeStore = sharedThemeStore ?? ThemeStore()
    sharedThemeStore = themeStore
    let customStore = sharedCustomStore ?? CustomThemeStore()
    sharedCustomStore = customStore
    themeStore.customStore = customStore
    let fontStore = sharedFontStore ?? FontStore()
    sharedFontStore = fontStore
    let backgroundStore = sharedBackgroundStore ?? BackgroundStore()
    sharedBackgroundStore = backgroundStore
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 520),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
    window.title = titleFor(layout: layout)
    window.isReleasedWhenClosed = false
    window.center()

    let root = DetachedRootView(layout: layout, store: store, window: window)
      .environment(themeStore)
      .environment(customStore)
      .environment(fontStore)
      .environment(backgroundStore)
      .environment(\.currentLayoutStore, layout)
    window.contentViewController = NSHostingController(rootView: root)

    let controller = NSWindowController(window: window)
    controllers.append(controller)
    window.delegate = WindowCleanup.shared
    controller.showWindow(nil)
    window.makeKeyAndOrderFront(nil)
  }

  /// 창 타이틀 계산: pane 1개면 그 이름, 여러개면 " · " 로 연결. 이름 다 비면 "CusTerminal".
  static func titleFor(layout: LayoutStore) -> String {
    let names = layout.columns
      .flatMap(\.sessions)
      .map(\.name)
      .filter { !$0.isEmpty }
    if names.isEmpty { return "CusTerminal" }
    return names.joined(separator: " · ")
  }

  fileprivate static func remove(controller: NSWindowController) {
    controllers.removeAll { $0 === controller }
  }
}

/// 새 창 닫힐 때 controllers 배열에서 제거.
private final class WindowCleanup: NSObject, NSWindowDelegate {
  static let shared = WindowCleanup()
  func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow,
          let controller = window.windowController
    else { return }
    DetachedWindowController.remove(controller: controller)
  }
}

/// 새 창의 root: 왼쪽에 자주 쓰는 커맨드 사이드바, 오른쪽에 pane.
/// window 참조를 받아 세션 이름 변경 시 창 타이틀을 실시간 갱신한다.
private struct DetachedRootView: View {
  @ObservedObject var layout: LayoutStore
  @Bindable var store: CommandStore
  weak var window: NSWindow?
  @State private var sidebarVisible: Bool = true
  @State private var sidebarWidth: CGFloat = 260

  var body: some View {
    SidebarSplit(
      sidebarVisible: $sidebarVisible,
      sidebarWidth: $sidebarWidth,
      sidebar: { CommandListView(store: store) },
      content: {
        VStack(spacing: 0) {
          HStack(spacing: 4) {
            SidebarToggleButton(visible: $sidebarVisible)
            Spacer()
          }
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))

          Group {
            if layout.columns.isEmpty {
              VStack {
                Text("모든 pane 이 닫혔습니다")
                  .foregroundStyle(.secondary)
                Text("이 창을 닫으세요 (⌘W)")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color.black)
            } else {
              DetachedLayoutContainer(layout: layout)
                .background(Color.black)
            }
          }
        }
      }
    )
    // 세션 이름/구성 변경 시 창 타이틀 재계산.
    .onReceive(layout.objectWillChange) { _ in
      DispatchQueue.main.async { updateTitle() }
    }
    .onAppear { updateTitle() }
    // 이름 변경 감지: 모든 세션의 objectWillChange 를 개별 구독하기는 번거로우니
    // 창 활성화될 때도 한 번 더 갱신.
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      updateTitle()
    }
    // pane 별 이름 변경 즉시 반영을 위해 자식들이 windowTitleUpdater 를 통해 트리거.
    .environment(\.windowTitleUpdater, WindowTitleUpdater { updateTitle() })
  }

  private func updateTitle() {
    window?.title = DetachedWindowController.titleFor(layout: layout)
  }
}

/// 자식 뷰(pane 헤더의 이름 편집기)가 창 타이틀 갱신을 요청할 수 있도록 하는 환경값.
struct WindowTitleUpdater {
  let trigger: () -> Void
  func callAsFunction() { trigger() }
}

private struct WindowTitleUpdaterKey: EnvironmentKey {
  static let defaultValue = WindowTitleUpdater(trigger: {})
}

extension EnvironmentValues {
  var windowTitleUpdater: WindowTitleUpdater {
    get { self[WindowTitleUpdaterKey.self] }
    set { self[WindowTitleUpdaterKey.self] = newValue }
  }
}

/// ContentView 의 LayoutContainer 와 동일 동작이지만 파일 분리 목적으로 별도 타입.
private struct DetachedLayoutContainer: View {
  @ObservedObject var layout: LayoutStore

  var body: some View {
    SplitContainer(
      isVertical: true,
      items: layout.columns.map { column in
        SplitItem(id: column.id, view: AnyView(DetachedColumnView(layout: layout, column: column)))
      }
    )
  }
}

private struct DetachedColumnView: View {
  @ObservedObject var layout: LayoutStore
  @ObservedObject var column: TerminalColumn

  var body: some View {
    SplitContainer(
      isVertical: false,
      items: column.sessions.map { session in
        SplitItem(id: session.id, view: AnyView(DetachedPaneChrome(layout: layout, session: session)))
      }
    )
  }
}

private struct DetachedPaneChrome: View {
  @ObservedObject var layout: LayoutStore
  @ObservedObject var session: TerminalSession
  @Environment(\.windowTitleUpdater) private var titleUpdater
  @Environment(ThemeStore.self) private var themeStore
  @Environment(FontStore.self) private var fontStore
  @Environment(BackgroundStore.self) private var backgroundStore

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        PaneDragHandle(sessionID: session.id)
          .frame(width: 22, height: 18)
          .help("드래그해서 다른 pane 의 상/하/좌/우 로 이동")
        DetachedPaneNameLabel(session: session, onCommit: titleUpdater.callAsFunction)
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
        Button {
          layout.splitVertical(after: session.id)
        } label: {
          Image(systemName: "plus.rectangle.portrait").frame(width: 18, height: 16)
        }
        .buttonStyle(.borderless)
        .help("세로 분할")

        Button {
          layout.splitHorizontal(after: session.id)
        } label: {
          Image(systemName: "plus.rectangle").frame(width: 18, height: 16)
        }
        .buttonStyle(.borderless)
        .help("가로 분할")

        Button {
          detachToNewWindow()
        } label: {
          Image(systemName: "rectangle.portrait.and.arrow.right").frame(width: 18, height: 16)
        }
        .buttonStyle(.borderless)
        .help("새 창으로 분리")

        Button {
          layout.remove(session.id)
        } label: {
          Image(systemName: "xmark").frame(width: 18, height: 16)
        }
        .buttonStyle(.borderless)
        .help("닫기")
      }
      .font(.system(size: 11, weight: .medium))
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))

      ZStack {
        TerminalPane(session: session)
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

/// 새 창용 pane 이름 라벨. 편집 완료 시 창 타이틀도 함께 갱신.
private struct DetachedPaneNameLabel: View {
  @ObservedObject var session: TerminalSession
  let onCommit: () -> Void
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
          .onExitCommand { isEditing = false }
          .onAppear { focused = true }
      } else {
        Text(session.name.isEmpty ? "이름 없음" : session.name)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(session.name.isEmpty ? .tertiary : .primary)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: 160, alignment: .leading)
          .contentShape(Rectangle())
          .help("더블클릭해서 pane 이름 편집")
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
    onCommit()
  }
}
