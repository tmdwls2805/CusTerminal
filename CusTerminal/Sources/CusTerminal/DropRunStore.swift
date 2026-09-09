import Foundation
import SwiftUI

/// 카드 드롭 시 자동 실행할지 여부. 기본값 = false (텍스트만 얹음).
/// drop-run.json 에 영속화.
@Observable
final class DropRunStore {
  var autoRun: Bool = false {
    didSet { if oldValue != autoRun { save() } }
  }

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("drop-run.json")
    load()
  }

  private struct Persisted: Codable { var autoRun: Bool }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data)
    else { return }
    autoRun = p.autoRun
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(Persisted(autoRun: autoRun)) else { return }
    try? data.write(to: fileURL)
  }
}
