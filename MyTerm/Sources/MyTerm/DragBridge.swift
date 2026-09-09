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

  private let topBar = NSView()
  private let bottomBar = NSView()
  private let leftBar = NSView()
  private let rightBar = NSView()
  private var lastEdge: LayoutStore.DropEdge = .top
  private var observer: NSObjectProtocol?

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    registerForDraggedTypes([paneMovePasteboardType])
    for bar in [topBar, bottomBar, leftBar, rightBar] {
      bar.wantsLayer = true
      bar.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor
      bar.isHidden = true
      addSubview(bar)
    }
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
    let barW: CGFloat = 4
    topBar.frame = NSRect(x: 0, y: bounds.height - barW, width: bounds.width, height: barW)
    bottomBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barW)
    leftBar.frame = NSRect(x: 0, y: 0, width: barW, height: bounds.height)
    rightBar.frame = NSRect(x: bounds.width - barW, y: 0, width: barW, height: bounds.height)
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
    hideAllBars()
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer { hideAllBars() }
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

  private func hideAllBars() {
    topBar.isHidden = true
    bottomBar.isHidden = true
    leftBar.isHidden = true
    rightBar.isHidden = true
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
      // dy 가 양수면 위쪽 → top
      edge = dy > 0 ? .top : .bottom
    }
    lastEdge = edge
    hideAllBars()
    switch edge {
    case .top: topBar.isHidden = false
    case .bottom: bottomBar.isHidden = false
    case .left: leftBar.isHidden = false
    case .right: rightBar.isHidden = false
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
