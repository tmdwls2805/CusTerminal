import Foundation
import SwiftUI
import AppKit

/// 배경 적용 모드 (테마와 동일 패턴).
enum BackgroundMode: String, Codable {
  case global
  case perPane
}

/// 이미지가 pane 을 채우는 방식.
enum BackgroundFit: String, Codable, CaseIterable, Identifiable {
  case fill    // 잘라서 채움 (aspect fill)
  case fit     // 여백 두고 맞춤 (aspect fit)
  case stretch // 늘림 (비율 무시)
  var id: String { rawValue }
  var label: String {
    switch self {
    case .fill: return "채움"
    case .fit: return "맞춤"
    case .stretch: return "늘림"
    }
  }
}

/// pane 배경 설정 하나. 파일 이름은 CusTerminal/backgrounds/ 안 상대 경로.
struct BackgroundChoice: Equatable, Codable {
  var fileName: String     // "bg-abc123.jpg" 등. 빈 문자열 = 배경 없음
  var opacity: Double      // 0.0 ~ 1.0
  var fit: BackgroundFit
  var darkenAmount: Double // 0.0 ~ 1.0 (0=원본, 1=완전 검정 오버레이)

  static let none = BackgroundChoice(fileName: "", opacity: 0.35, fit: .fill, darkenAmount: 0.3)
  var isEmpty: Bool { fileName.isEmpty }
}

/// 전역 + 세션별 배경 설정을 관리. background.json 에 영속화.
/// 이미지 파일 자체는 CusTerminal/backgrounds/ 에 복사 저장.
@Observable
final class BackgroundStore {
  var mode: BackgroundMode = .global {
    didSet { if oldValue != mode { save() } }
  }
  var globalChoice: BackgroundChoice = .none {
    didSet { if oldValue != globalChoice { save() } }
  }

  let backgroundsDir: URL
  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.backgroundsDir = dir.appendingPathComponent("backgrounds", isDirectory: true)
    self.fileURL = dir.appendingPathComponent("background.json")
    try? FileManager.default.createDirectory(at: backgroundsDir, withIntermediateDirectories: true)
    load()
  }

  /// 특정 세션에 실제 적용될 배경.
  func backgroundFor(session: TerminalSession) -> BackgroundChoice {
    switch mode {
    case .global: return globalChoice
    case .perPane: return session.backgroundOverride ?? globalChoice
    }
  }

  func apply(_ choice: BackgroundChoice, to target: TerminalSession?) {
    switch mode {
    case .global:
      globalChoice = choice
    case .perPane:
      if let target { target.backgroundOverride = choice }
      else { globalChoice = choice }
    }
  }

  /// 파일을 앱 backgrounds/ 폴더로 복사하고 새 파일명 반환.
  /// 실패 시 nil.
  func importImage(from sourceURL: URL) -> String? {
    let ext = sourceURL.pathExtension.isEmpty ? "img" : sourceURL.pathExtension
    let name = "bg-\(UUID().uuidString.prefix(8)).\(ext)"
    let dest = backgroundsDir.appendingPathComponent(name)
    do {
      try FileManager.default.copyItem(at: sourceURL, to: dest)
      return name
    } catch {
      return nil
    }
  }

  /// backgrounds/ 안 파일의 절대 경로 URL.
  func url(for fileName: String) -> URL? {
    guard !fileName.isEmpty else { return nil }
    return backgroundsDir.appendingPathComponent(fileName)
  }

  /// NSImage 로 로드.
  func loadImage(_ fileName: String) -> NSImage? {
    guard let url = url(for: fileName) else { return nil }
    return NSImage(contentsOf: url)
  }

  /// 되돌리기.
  func resetToDefaults(sessions: [TerminalSession]) {
    mode = .global
    globalChoice = .none
    for s in sessions { s.backgroundOverride = nil }
  }

  // MARK: 영속화

  private struct Persisted: Codable {
    var mode: BackgroundMode
    var globalChoice: BackgroundChoice
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data)
    else { return }
    self.mode = p.mode
    self.globalChoice = p.globalChoice
  }

  private func save() {
    let p = Persisted(mode: mode, globalChoice: globalChoice)
    guard let data = try? JSONEncoder().encode(p) else { return }
    try? data.write(to: fileURL)
  }
}
