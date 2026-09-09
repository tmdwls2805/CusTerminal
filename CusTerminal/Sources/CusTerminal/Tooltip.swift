import SwiftUI
import AppKit

/// hover 즉시 표시되는 툴팁. NSPanel 을 창 위에 띄워 어떤 부모 clipping 도 무시.
struct TooltipModifier: ViewModifier {
  let text: String
  @State private var frame: CGRect = .zero

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear
            .onAppear {
              // 화면 좌표로 변환해서 저장 (팝업 위치 계산용).
              frame = proxy.frame(in: .global)
            }
            .onChange(of: proxy.frame(in: .global)) { _, new in
              frame = new
            }
        }
      )
      .background(TooltipHoverHost(text: text))
  }
}

extension View {
  func tooltip(_ text: String) -> some View {
    modifier(TooltipModifier(text: text))
  }
}

/// 자기 자신을 target 으로 hover 를 감지하고, NSPanel 을 띄운다.
private struct TooltipHoverHost: NSViewRepresentable {
  let text: String

  func makeNSView(context: Context) -> HoverTrackingView {
    let v = HoverTrackingView()
    v.text = text
    return v
  }

  func updateNSView(_ nsView: HoverTrackingView, context: Context) {
    nsView.text = text
  }
}

private final class HoverTrackingView: NSView {
  var text: String = "" {
    didSet {
      if TooltipPanel.shared.currentOwner === self { TooltipPanel.shared.setText(text) }
    }
  }
  private var trackingArea: NSTrackingArea?

  override var frame: NSRect {
    didSet {
      updateTrackingAreas()
    }
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    guard !text.isEmpty, let window = self.window else { return }
    // 이 뷰의 화면 좌표.
    let viewFrameInWindow = convert(bounds, to: nil)
    let viewFrameOnScreen = window.convertToScreen(viewFrameInWindow)
    TooltipPanel.shared.show(text: text, near: viewFrameOnScreen, owner: self)
  }

  override func mouseExited(with event: NSEvent) {
    if TooltipPanel.shared.currentOwner === self {
      TooltipPanel.shared.hide()
    }
  }

  // 자기 뷰 hitTest 는 뒤로 통과 (원본 SwiftUI 뷰가 클릭·드래그 받음).
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// 앱 전역 단 하나의 툴팁 패널. 하나만 띄우고 위치·텍스트만 바꿔 재사용.
private final class TooltipPanel {
  static let shared = TooltipPanel()
  private let panel: NSPanel
  private let label: NSTextField
  private let container: NSView
  weak var currentOwner: HoverTrackingView?

  private init() {
    let padding: CGFloat = 8
    let panelFrame = NSRect(x: 0, y: 0, width: 100, height: 30)
    panel = NSPanel(
      contentRect: panelFrame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hidesOnDeactivate = false

    container = NSView(frame: panelFrame)
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
    container.layer?.cornerRadius = 6
    container.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
    container.layer?.borderWidth = 0.5

    label = NSTextField(labelWithString: "")
    label.font = .systemFont(ofSize: 11)
    label.textColor = .white
    label.lineBreakMode = .byWordWrapping
    label.maximumNumberOfLines = 0
    label.preferredMaxLayoutWidth = 300
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
      label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
      label.topAnchor.constraint(equalTo: container.topAnchor, constant: padding - 2),
      label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -(padding - 2)),
    ])
    panel.contentView = container
  }

  func setText(_ text: String) {
    label.stringValue = text
    resize()
  }

  func show(text: String, near viewFrameOnScreen: NSRect, owner: HoverTrackingView) {
    label.stringValue = text
    resize()
    let size = panel.frame.size
    let gap: CGFloat = 8
    // macOS 화면 좌표계는 좌하단 원점.
    //  화면상 "뷰 아래" = 좌표 y 가 뷰 minY 보다 작은 곳.
    //  → 아래 배치: y = viewFrameOnScreen.minY - size.height - gap
    //  → 위 배치:   y = viewFrameOnScreen.maxY + gap
    var x = viewFrameOnScreen.midX - size.width / 2
    var y = viewFrameOnScreen.minY - size.height - gap   // 기본: 뷰 아래
    if let screen = owner.window?.screen ?? NSScreen.main {
      let vis = screen.visibleFrame
      // 아래 공간 부족(뷰가 화면 하단 근처) → 위로.
      if y < vis.minY + 4 {
        y = viewFrameOnScreen.maxY + gap
      }
      // x 는 화면 좌우 벗어나지 않게.
      x = min(max(x, vis.minX + 4), vis.maxX - size.width - 4)
      // 최종 y clamp.
      y = min(max(y, vis.minY + 4), vis.maxY - size.height - 4)
    }
    panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    panel.orderFrontRegardless()
    currentOwner = owner
  }

  func hide() {
    panel.orderOut(nil)
    currentOwner = nil
  }

  private func resize() {
    label.preferredMaxLayoutWidth = 300
    label.sizeToFit()
    let padding: CGFloat = 8
    let w = min(320, label.frame.width + padding * 2)
    let h = label.frame.height + padding * 2 - 4
    panel.setContentSize(NSSize(width: w, height: h))
  }
}
