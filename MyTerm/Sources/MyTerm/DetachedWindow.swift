import SwiftUI
import AppKit

/// 새 창으로 분리된 pane 들을 관리. 각 창은 자체 LayoutStore 를 가진다.
enum DetachedWindowController {
  private static var controllers: [NSWindowController] = []

  /// 커맨드 스토어는 메인 창과 공유해야 새 창에서도 같은 카드 목록이 보인다.
  static var sharedStore: CommandStore?

  static func open(session: TerminalSession) {
    let layout = LayoutStore(columns: [TerminalColumn(sessions: [session])])
    let store = sharedStore ?? CommandStore()
    sharedStore = store
    let root = DetachedRootView(layout: layout, store: store)
    let hosting = NSHostingController(rootView: root)
    let window = NSWindow(contentViewController: hosting)
    window.title = "MyTerm"
    window.setContentSize(NSSize(width: 900, height: 520))
    window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
    window.isReleasedWhenClosed = false
    window.center()

    let controller = NSWindowController(window: window)
    controllers.append(controller)
    window.delegate = WindowCleanup.shared
    controller.showWindow(nil)
    window.makeKeyAndOrderFront(nil)
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
private struct DetachedRootView: View {
  @ObservedObject var layout: LayoutStore
  @Bindable var store: CommandStore

  var body: some View {
    HStack(spacing: 0) {
      CommandListView(store: store)
        .frame(width: 260)
      Divider()
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

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        PaneDragHandle(sessionID: session.id)
          .frame(width: 22, height: 18)
          .help("드래그해서 다른 pane 의 상/하/좌/우 로 이동")
        Spacer()
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
