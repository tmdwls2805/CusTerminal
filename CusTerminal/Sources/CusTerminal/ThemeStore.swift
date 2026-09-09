import Foundation
import SwiftUI

/// 테마 적용 모드.
enum ThemeMode: String, Codable {
  case global   // 앱 전체가 같은 테마
  case perPane  // 각 pane 이 개별 테마
}

/// 테마 선택 + 모드를 관리하는 전역 스토어.
/// - 전역 모드: `globalThemeID` 를 세션들이 참조
/// - 세션별 모드: 각 세션이 자기 테마 오버라이드 보유
/// 저장은 프로젝트 폴더 안 theme.json (앱 재실행 후에도 유지).
@Observable
final class ThemeStore {
  var mode: ThemeMode = .global {
    didSet { if oldValue != mode { save() } }
  }
  var globalThemeID: String = "classic-dark" {
    didSet { if oldValue != globalThemeID { save() } }
  }

  /// 커스텀 테마 조회를 위한 약참조. ContentView 가 주입.
  weak var customStore: CustomThemeStore?

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("theme.json")
    load()
  }

  private var customThemes: [TerminalTheme] { customStore?.themes ?? [] }

  var globalTheme: TerminalTheme { ThemeCatalog.byID(globalThemeID, custom: customThemes) }

  /// 전역·세션별 모든 오버라이드를 초기값으로 되돌린다.
  /// - 전역 테마: classic-dark
  /// - 모드: global
  /// - 모든 세션의 개별 테마: 제거
  func resetToDefaults(sessions: [TerminalSession]) {
    mode = .global
    globalThemeID = "classic-dark"
    for s in sessions { s.themeIDOverride = nil }
  }

  func themeFor(session: TerminalSession) -> TerminalTheme {
    switch mode {
    case .global: return globalTheme
    case .perPane:
      if let id = session.themeIDOverride { return ThemeCatalog.byID(id, custom: customThemes) }
      return globalTheme
    }
  }

  /// 사용자가 팔레트에서 테마를 골랐을 때.
  /// - 전역 모드: 전역 테마 변경
  /// - 세션 모드: 대상 세션에만 적용 (target=nil 이면 전역 fallback 갱신)
  func apply(themeID: String, to target: TerminalSession?) {
    switch mode {
    case .global:
      globalThemeID = themeID
    case .perPane:
      if let target {
        target.themeIDOverride = themeID
      } else {
        globalThemeID = themeID
      }
    }
  }

  // MARK: - 영속화

  private struct Persisted: Codable {
    var mode: ThemeMode
    var globalThemeID: String
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data)
    else { return }
    self.mode = p.mode
    self.globalThemeID = p.globalThemeID
  }

  private func save() {
    let p = Persisted(mode: mode, globalThemeID: globalThemeID)
    guard let data = try? JSONEncoder().encode(p) else { return }
    try? data.write(to: fileURL)
  }
}
