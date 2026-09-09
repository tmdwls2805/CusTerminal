import Foundation
import SwiftUI
import AppKit

/// 사용자 커스텀 테마 저장소. 프로젝트 폴더 custom-themes.json 에 영속화.
@Observable
final class CustomThemeStore {
  var themes: [TerminalTheme] = []

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("custom-themes.json")
    load()
  }

  func upsert(_ theme: TerminalTheme) {
    if let idx = themes.firstIndex(where: { $0.id == theme.id }) {
      themes[idx] = theme
    } else {
      themes.append(theme)
    }
    save()
  }

  func remove(id: String) {
    themes.removeAll { $0.id == id }
    save()
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let list = try? JSONDecoder().decode([TerminalTheme].self, from: data)
    else { return }
    themes = list
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(themes) else { return }
    try? data.write(to: fileURL)
  }
}

// MARK: - NSColor → hex 변환 (편집 시트에서 사용)

extension NSColor {
  /// sRGB "#RRGGBB" 문자열로 변환. 실패 시 "#000000".
  var srgbHex: String {
    guard let c = usingColorSpace(.sRGB) else { return "#000000" }
    let r = Int((c.redComponent * 255).rounded().clamped(to: 0...255))
    let g = Int((c.greenComponent * 255).rounded().clamped(to: 0...255))
    let b = Int((c.blueComponent * 255).rounded().clamped(to: 0...255))
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}

private extension CGFloat {
  func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
    Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
  }
}
