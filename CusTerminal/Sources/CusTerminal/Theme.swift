import AppKit
import Foundation

/// 터미널 색상 테마. 배경/전경/커서/선택 색상만 정의.
struct TerminalTheme: Identifiable, Codable, Equatable, Hashable {
  let id: String
  let name: String
  /// hex "#RRGGBB" 로 저장 (JSON 친화 + NSColor 변환).
  let backgroundHex: String
  let foregroundHex: String
  let cursorHex: String
  let selectionHex: String

  var background: NSColor { NSColor(hex: backgroundHex) ?? .black }
  var foreground: NSColor { NSColor(hex: foregroundHex) ?? .white }
  var cursor: NSColor { NSColor(hex: cursorHex) ?? .white }
  var selection: NSColor { NSColor(hex: selectionHex) ?? .darkGray }

  /// 사이드바 미리보기용 짧은 그라디언트(배경→전경).
  var swatchColors: [NSColor] { [background, foreground] }
}

/// 앱 내장 테마 20종. 개발자 클래식 5 + 사이버 4 + 인기 팔레트 6 + 귀여운 5.
enum ThemeCatalog {
  static let all: [TerminalTheme] = [
    // MARK: 개발자 클래식
    .init(id: "classic-dark",  name: "Classic Dark",   backgroundHex: "#000000", foregroundHex: "#FFFFFF", cursorHex: "#FFFFFF", selectionHex: "#3D3D3D"),
    .init(id: "light",         name: "Light",          backgroundHex: "#FFFFFF", foregroundHex: "#1B1B1B", cursorHex: "#1B1B1B", selectionHex: "#B4D5FE"),
    .init(id: "terminal-green",name: "Terminal Green", backgroundHex: "#000000", foregroundHex: "#33FF33", cursorHex: "#33FF33", selectionHex: "#0F5F0F"),
    .init(id: "retro-amber",   name: "Retro Amber",    backgroundHex: "#0B0B0B", foregroundHex: "#FFB000", cursorHex: "#FFB000", selectionHex: "#5C3D00"),
    .init(id: "monochrome",    name: "Monochrome",     backgroundHex: "#1E1E1E", foregroundHex: "#D0D0D0", cursorHex: "#D0D0D0", selectionHex: "#3E3E3E"),

    // MARK: 사이버 / 해커
    .init(id: "matrix",        name: "Matrix",         backgroundHex: "#050805", foregroundHex: "#00FF41", cursorHex: "#00FF41", selectionHex: "#003D10"),
    .init(id: "cyberpunk",     name: "Cyberpunk",      backgroundHex: "#0A0014", foregroundHex: "#FF00A0", cursorHex: "#00FFF7", selectionHex: "#3A0044"),
    .init(id: "hacker-blue",   name: "Hacker Blue",    backgroundHex: "#01111F", foregroundHex: "#00E0FF", cursorHex: "#00E0FF", selectionHex: "#0A3040"),
    .init(id: "neon-purple",   name: "Neon Purple",    backgroundHex: "#0A000A", foregroundHex: "#C471FF", cursorHex: "#C471FF", selectionHex: "#3B0C58"),

    // MARK: 인기 팔레트
    .init(id: "dracula",       name: "Dracula",        backgroundHex: "#282A36", foregroundHex: "#F8F8F2", cursorHex: "#BD93F9", selectionHex: "#44475A"),
    .init(id: "nord",          name: "Nord",           backgroundHex: "#2E3440", foregroundHex: "#D8DEE9", cursorHex: "#88C0D0", selectionHex: "#434C5E"),
    .init(id: "gruvbox-dark",  name: "Gruvbox Dark",   backgroundHex: "#282828", foregroundHex: "#EBDBB2", cursorHex: "#FE8019", selectionHex: "#504945"),
    .init(id: "tokyo-night",   name: "Tokyo Night",    backgroundHex: "#1A1B26", foregroundHex: "#C0CAF5", cursorHex: "#7AA2F7", selectionHex: "#33467C"),
    .init(id: "solarized-dark",name: "Solarized Dark", backgroundHex: "#002B36", foregroundHex: "#93A1A1", cursorHex: "#93A1A1", selectionHex: "#073642"),
    .init(id: "monokai",       name: "Monokai",        backgroundHex: "#272822", foregroundHex: "#F8F8F2", cursorHex: "#F92672", selectionHex: "#49483E"),

    // MARK: 귀여운
    .init(id: "peach-soft",    name: "Peach Soft",     backgroundHex: "#FFF3E9", foregroundHex: "#C54B4B", cursorHex: "#FF7A59", selectionHex: "#FFD3B6"),
    .init(id: "sakura",        name: "Sakura",         backgroundHex: "#FFE9F1", foregroundHex: "#B8005E", cursorHex: "#E91E63", selectionHex: "#FFB6D0"),
    .init(id: "mint-cream",    name: "Mint Cream",     backgroundHex: "#E8F8F0", foregroundHex: "#0F5A3E", cursorHex: "#1BA97A", selectionHex: "#BDECD6"),
    .init(id: "lavender-dream",name: "Lavender Dream", backgroundHex: "#EFE7FA", foregroundHex: "#4A2E7A", cursorHex: "#7C4DFF", selectionHex: "#D6C6F0"),
    .init(id: "bubblegum",     name: "Bubblegum",      backgroundHex: "#FFEEF7", foregroundHex: "#B0006B", cursorHex: "#FF3EA5", selectionHex: "#FFC5E1"),
  ]

  static func byID(_ id: String, custom: [TerminalTheme] = []) -> TerminalTheme {
    if let t = all.first(where: { $0.id == id }) { return t }
    if let t = custom.first(where: { $0.id == id }) { return t }
    return all[0]
  }
}

// MARK: - NSColor <-> hex

extension NSColor {
  convenience init?(hex: String) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
    let r = CGFloat((value >> 16) & 0xFF) / 255
    let g = CGFloat((value >> 8) & 0xFF) / 255
    let b = CGFloat(value & 0xFF) / 255
    self.init(srgbRed: r, green: g, blue: b, alpha: 1)
  }
}
