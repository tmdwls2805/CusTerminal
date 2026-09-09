import SwiftUI
import AppKit

/// SwiftUI ColorPicker 대안. 클릭하면 NSColorPanel 을 부모 창에 가깝게 띄우고,
/// 색 변화가 실시간으로 바인딩에 반영된다.
/// 시트가 닫히면 (뷰가 사라지면) 이 well 이 활성 target 이면 패널도 닫는다.
struct ColorWell: NSViewRepresentable {
  @Binding var color: Color

  func makeNSView(context: Context) -> NSColorWell {
    let well = NSColorWell()
    well.color = NSColor(color)
    well.target = context.coordinator
    well.action = #selector(Coordinator.colorChanged(_:))
    context.coordinator.well = well
    return well
  }

  func updateNSView(_ nsView: NSColorWell, context: Context) {
    let target = NSColor(color)
    if !target.isEqual(nsView.color) {
      nsView.color = target
    }
  }

  static func dismantleNSView(_ nsView: NSColorWell, coordinator: Coordinator) {
    let panel = NSColorPanel.shared
    // 이 well 이 지금 패널의 활성 대상이면 패널 닫기.
    if panel.isVisible, let active = coordinator.well, active.isActive {
      active.deactivate()
      panel.orderOut(nil)
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(color: $color) }

  final class Coordinator: NSObject {
    let color: Binding<Color>
    weak var well: NSColorWell?

    init(color: Binding<Color>) { self.color = color }

    @objc func colorChanged(_ sender: NSColorWell) {
      color.wrappedValue = Color(nsColor: sender.color)
    }
  }
}
