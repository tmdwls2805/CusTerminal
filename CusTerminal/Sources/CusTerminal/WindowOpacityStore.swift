import Foundation
import SwiftUI
import AppKit

/// 창 투명도 (전역). 모든 창에 동일 적용.
/// window-opacity.json 에 영속화.
@Observable
final class WindowOpacityStore {
  /// 0.4 ~ 1.0 (0.4 미만은 사용성 떨어져 하한).
  var opacity: Double = 1.0 {
    didSet {
      if oldValue != opacity {
        save()
        applyToAllWindows()
      }
    }
  }

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("window-opacity.json")
    load()
  }

  /// 모든 NSApp.windows 에 즉시 적용.
  func applyToAllWindows() {
    for window in NSApp.windows where window.isVisible {
      apply(to: window)
    }
  }

  /// 특정 창에 적용. 창이 처음 등장할 때도 이걸로 초기값 세팅.
  func apply(to window: NSWindow) {
    window.alphaValue = CGFloat(opacity)
  }

  private struct Persisted: Codable { var opacity: Double }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
    opacity = max(0.4, min(1.0, p.opacity))
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(Persisted(opacity: opacity)) else { return }
    try? data.write(to: fileURL)
  }
}
