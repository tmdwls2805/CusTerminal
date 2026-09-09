import SwiftUI
import AppKit

/// pane 이동 드래그의 pasteboard 타입.
let paneMovePasteboardType = NSPasteboard.PasteboardType("com.silverslab.myterm.pane-move")

/// 드래그 세션 상태를 앱 전역에서 추적 → drop 오버레이가 언제 활성화될지 판단.
final class DragCoordinator {
  static let shared = DragCoordinator()
  private(set) var isDraggingPane: Bool = false
  /// 활성 상태 바뀔 때 오버레이들이 hitTest / 시각 상태 갱신하도록 브로드캐스트.
  static let didChangeNotification = Notification.Name("MyTermDragCoordinatorDidChange")

  func begin() {
    isDraggingPane = true
    NotificationCenter.default.post(name: DragCoordinator.didChangeNotification, object: nil)
  }
  func end() {
    isDraggingPane = false
    NotificationCenter.default.post(name: DragCoordinator.didChangeNotification, object: nil)
  }
}

// MARK: - 드래그 소스 (헤더 왼쪽 햄버거 아이콘)

final class DragSourceView: NSView, NSDraggingSource {
  var sessionID: UUID = UUID()
  private var mouseDownPoint: NSPoint = .zero
  private var dragStarted: Bool = false

  init() {
    super.init(frame: .zero)
    wantsLayer = true
  }
  required init?(coder: NSCoder) { fatalError() }

  override func mouseDown(with event: NSEvent) {
    mouseDownPoint = event.locationInWindow
    dragStarted = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard !dragStarted else { return }
    let dx = event.locationInWindow.x - mouseDownPoint.x
    let dy = event.locationInWindow.y - mouseDownPoint.y
    guard hypot(dx, dy) > 4 else { return }
    dragStarted = true

    let pbItem = NSPasteboardItem()
    pbItem.setString(sessionID.uuidString, forType: paneMovePasteboardType)
    let item = NSDraggingItem(pasteboardWriter: pbItem)
    item.setDraggingFrame(bounds, contents: snapshotImage())

    DragCoordinator.shared.begin()
    beginDraggingSession(with: [item], event: event, source: self)
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    return .move
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    DragCoordinator.shared.end()
  }

  private func snapshotImage() -> NSImage {
    guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return NSImage(size: bounds.size) }
    cacheDisplay(in: bounds, to: rep)
    let img = NSImage(size: bounds.size)
    img.addRepresentation(rep)
    return img
  }
}

/// SwiftUI 래퍼: 헤더에 넣을 드래그 핸들 (햄버거).
struct PaneDragHandle: NSViewRepresentable {
  let sessionID: UUID

  func makeNSView(context: Context) -> DragSourceView {
    let v = DragSourceView()
    v.sessionID = sessionID
    let icon = NSImageView(image: NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "pane 이동")!)
    icon.contentTintColor = .secondaryLabelColor
    icon.translatesAutoresizingMaskIntoConstraints = false
    v.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: v.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: v.centerYAnchor),
    ])
    return v
  }

  func updateNSView(_ nsView: DragSourceView, context: Context) {
    nsView.sessionID = sessionID
  }
}

// MARK: - 드롭 타깃 (pane 전체를 4분면으로 판정)

final class PaneDropOverlay: NSView {
  var targetSessionID: UUID = UUID()
  var onDrop: ((_ sourceID: UUID, _ edge: LayoutStore.DropEdge) -> Void)?

  /// IDEA 스타일: drop 위치의 절반 영역을 통짜 반투명으로 채워 "여기 이 크기로 들어감" 미리보기.
  private let highlight = NSView()
  private var lastEdge: LayoutStore.DropEdge = .top
  private var observer: NSObjectProtocol?

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    registerForDraggedTypes([paneMovePasteboardType])
    highlight.wantsLayer = true
    highlight.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.28).cgColor
    highlight.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
    highlight.layer?.borderWidth = 2
    highlight.layer?.cornerRadius = 4
    highlight.isHidden = true
    addSubview(highlight)
    observer = NotificationCenter.default.addObserver(
      forName: DragCoordinator.didChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.needsLayout = true
    }
  }
  required init?(coder: NSCoder) { fatalError() }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  override func layout() {
    super.layout()
    // hidden 이면 굳이 계산 안 함. 표시 중이면 lastEdge 로 위치 갱신.
    if !highlight.isHidden { updateHighlightFrame(edge: lastEdge) }
  }

  /// edge 방향의 절반 영역 rect. AppKit 좌하단 원점.
  private func rect(for edge: LayoutStore.DropEdge) -> NSRect {
    switch edge {
    case .top:
      return NSRect(x: 0, y: bounds.height / 2, width: bounds.width, height: bounds.height / 2)
    case .bottom:
      return NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height / 2)
    case .left:
      return NSRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
    case .right:
      return NSRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height)
    }
  }

  private func updateHighlightFrame(edge: LayoutStore.DropEdge) {
    // 살짝 안쪽으로 패딩해서 pane 경계와 겹치지 않게.
    let r = rect(for: edge).insetBy(dx: 2, dy: 2)
    // 부드러운 이동 애니메이션.
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.12
      ctx.allowsImplicitAnimation = true
      highlight.animator().frame = r
    }
  }

  /// 드래그 세션이 활성일 때만 오버레이가 마우스 이벤트를 받음.
  /// → 평상시엔 밑의 터미널이 클릭·스크롤 정상 수신.
  override func hitTest(_ point: NSPoint) -> NSView? {
    if DragCoordinator.shared.isDraggingPane {
      return super.hitTest(point)
    }
    return nil
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard isValidSource(sender) else { return [] }
    updateBars(for: sender)
    return .move
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard isValidSource(sender) else { return [] }
    updateBars(for: sender)
    return .move
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    hideHighlight()
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer { hideHighlight() }
    guard let s = sender.draggingPasteboard.string(forType: paneMovePasteboardType),
          let sourceID = UUID(uuidString: s),
          sourceID != targetSessionID
    else { return false }
    onDrop?(sourceID, lastEdge)
    return true
  }

  private func isValidSource(_ sender: NSDraggingInfo) -> Bool {
    guard let s = sender.draggingPasteboard.string(forType: paneMovePasteboardType),
          let id = UUID(uuidString: s) else { return false }
    return id != targetSessionID
  }

  private func hideHighlight() {
    highlight.isHidden = true
  }

  /// 4분면(N/S/E/W) 판정: 마우스 위치를 pane 중심에서의 각도로 나눔.
  /// AppKit 좌표계는 좌하단 원점.
  private func updateBars(for sender: NSDraggingInfo) {
    let p = convert(sender.draggingLocation, from: nil)
    let cx = bounds.midX
    let cy = bounds.midY
    let dx = p.x - cx
    let dy = p.y - cy

    let edge: LayoutStore.DropEdge
    if abs(dx) > abs(dy) {
      edge = dx < 0 ? .left : .right
    } else {
      // dy 양수 = 위쪽 = top
      edge = dy > 0 ? .top : .bottom
    }

    let edgeChanged = edge != lastEdge
    lastEdge = edge

    if highlight.isHidden {
      // 처음 등장: 애니메이션 없이 바로 위치 세팅 후 표시.
      highlight.frame = rect(for: edge).insetBy(dx: 2, dy: 2)
      highlight.isHidden = false
    } else if edgeChanged {
      updateHighlightFrame(edge: edge)
    }
  }
}

/// SwiftUI 래퍼: pane 위에 얹을 4방향 드롭 오버레이.
struct PaneDropTarget: NSViewRepresentable {
  let targetSessionID: UUID
  let onDrop: (_ sourceID: UUID, _ edge: LayoutStore.DropEdge) -> Void

  func makeNSView(context: Context) -> PaneDropOverlay {
    let v = PaneDropOverlay()
    v.targetSessionID = targetSessionID
    v.onDrop = onDrop
    return v
  }
  func updateNSView(_ nsView: PaneDropOverlay, context: Context) {
    nsView.targetSessionID = targetSessionID
    nsView.onDrop = onDrop
  }
}
