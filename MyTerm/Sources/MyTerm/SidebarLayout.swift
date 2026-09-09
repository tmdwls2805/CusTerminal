import SwiftUI
import AppKit

/// 왼쪽 사이드바(커맨드 저장소) + 오른쪽 컨텐츠. 사이드바는:
/// - divider 잡고 드래그로 폭 조절 (150~500)
/// - 헤더 토글 버튼으로 완전 숨김/보이기
///
/// NSSplitView 대신 SwiftUI HStack + 애니메이션 폭 조절. 단순하고 안정적.
struct SidebarSplit<Sidebar: View, Content: View>: View {
  @Binding var sidebarVisible: Bool
  @Binding var sidebarWidth: CGFloat
  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content

  private let minWidth: CGFloat = 180
  private let maxWidth: CGFloat = 500

  var body: some View {
    HStack(spacing: 0) {
      if sidebarVisible {
        sidebar()
          .frame(width: sidebarWidth)
          .clipped()
          .transition(.move(edge: .leading).combined(with: .opacity))

        ResizeHandle(width: $sidebarWidth, min: minWidth, max: maxWidth)
          .frame(width: 4)
      }

      content()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // 창 전체를 채우도록 강제. 이거 없으면 HStack 이 자기 필요 크기만 잡아
    // 사이드바와 content 사이/오른쪽에 회색 빈 공간이 남음.
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// 4px 폭의 세로 divider. hover 시 커서 변경, 드래그하면 사이드바 폭 변경.
private struct ResizeHandle: NSViewRepresentable {
  @Binding var width: CGFloat
  let min: CGFloat
  let max: CGFloat

  func makeNSView(context: Context) -> ResizeHandleView {
    let v = ResizeHandleView()
    v.onChange = { delta in
      let next = width + delta
      width = Swift.min(Swift.max(next, min), max)
    }
    return v
  }
  func updateNSView(_ nsView: ResizeHandleView, context: Context) {
    nsView.onChange = { delta in
      let next = width + delta
      width = Swift.min(Swift.max(next, min), max)
    }
  }
}

final class ResizeHandleView: NSView {
  var onChange: ((CGFloat) -> Void)?
  private var trackingArea: NSTrackingArea?

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.separatorColor.cgColor
  }
  required init?(coder: NSCoder) { fatalError() }

  override var intrinsicContentSize: NSSize { NSSize(width: 4, height: NSView.noIntrinsicMetric) }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
      owner: self, userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  override func cursorUpdate(with event: NSEvent) {
    NSCursor.resizeLeftRight.set()
  }

  override func mouseDragged(with event: NSEvent) {
    onChange?(event.deltaX)
  }
}

/// 사이드바 접힘/펴짐 토글 버튼. 헤더에 배치.
struct SidebarToggleButton: View {
  @Binding var visible: Bool

  var body: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.18)) { visible.toggle() }
    } label: {
      Image(systemName: visible ? "sidebar.left" : "sidebar.leading")
        .frame(width: 22, height: 20)
    }
    .buttonStyle(.borderless)
    .help(visible ? "사이드바 숨기기" : "사이드바 보이기")
    .keyboardShortcut("b", modifiers: .command)
  }
}
