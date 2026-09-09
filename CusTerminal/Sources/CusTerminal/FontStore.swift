import Foundation
import SwiftUI
import AppKit

/// 폰트 적용 모드 (테마와 동일 패턴).
enum FontMode: String, Codable {
  case global
  case perPane
}

/// 폰트 이름 + 크기.
struct TerminalFontChoice: Equatable, Codable {
  var name: String   // NSFont 폰트 이름 (예: "Menlo", "SF Mono Regular")
  var size: CGFloat  // 포인트

  static let `default` = TerminalFontChoice(name: "Menlo", size: 12)
}

/// 전역 + 세션별 폰트를 관리. `font.json` 에 영속화.
@Observable
final class FontStore {
  var mode: FontMode = .global {
    didSet { if oldValue != mode { save() } }
  }
  var globalFont: TerminalFontChoice = .default {
    didSet { if oldValue != globalFont { save() } }
  }

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("font.json")
    load()
  }

  /// 특정 세션에 실제로 적용될 폰트.
  func fontFor(session: TerminalSession) -> TerminalFontChoice {
    switch mode {
    case .global: return globalFont
    case .perPane: return session.fontOverride ?? globalFont
    }
  }

  func apply(_ choice: TerminalFontChoice, to target: TerminalSession?) {
    switch mode {
    case .global:
      globalFont = choice
    case .perPane:
      if let target { target.fontOverride = choice }
      else { globalFont = choice }
    }
  }

  /// 전역·세션별 모든 오버라이드를 초기값으로 되돌린다.
  /// - 전역 폰트: Menlo 12pt (TerminalFontChoice.default)
  /// - 모드: global
  /// - 모든 세션의 개별 폰트: 제거
  func resetToDefaults(sessions: [TerminalSession]) {
    mode = .global
    globalFont = .default
    for s in sessions { s.fontOverride = nil }
  }

  // MARK: 영속화

  private struct Persisted: Codable {
    var mode: FontMode
    var globalFont: TerminalFontChoice
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data)
    else { return }
    self.mode = p.mode
    self.globalFont = p.globalFont
  }

  private func save() {
    let p = Persisted(mode: mode, globalFont: globalFont)
    guard let data = try? JSONEncoder().encode(p) else { return }
    try? data.write(to: fileURL)
  }
}

// MARK: - 시스템 폰트 목록

enum FontCatalog {
  /// 개발자 자주 쓰는 모노스페이스 우선 + 시스템 모든 monospaced 폰트.
  /// (없으면 자동 제외)
  static var monospaced: [String] {
    let curated = [
      "SF Mono", "Menlo", "Monaco", "Courier", "Courier New",
      "JetBrains Mono", "Fira Code", "Fira Mono", "Cascadia Code",
      "Source Code Pro", "IBM Plex Mono", "Hack", "Iosevka", "PT Mono",
      "D2Coding", "NanumGothicCoding", "Andale Mono",
    ]
    let manager = NSFontManager.shared
    let installed = Set(manager.availableFontFamilies)
    // curated 순서 유지하면서 설치된 것만.
    var seen = Set<String>()
    var result: [String] = []
    for name in curated where installed.contains(name) && seen.insert(name).inserted {
      result.append(name)
    }
    // 그 외 monospaced 로 알려진 폰트도 뒤에 추가.
    let extra = installed.filter { family in
      guard !seen.contains(family) else { return false }
      // NSFont 로 만들어보고 fixedPitch trait 여부 확인.
      guard let font = NSFont(name: family, size: 12) else { return false }
      let traits = NSFontManager.shared.traits(of: font)
      return traits.contains(.fixedPitchFontMask)
    }.sorted()
    for name in extra where seen.insert(name).inserted {
      result.append(name)
    }
    return result
  }
}
