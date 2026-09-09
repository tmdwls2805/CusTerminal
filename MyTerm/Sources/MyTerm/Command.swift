import Foundation
import SwiftUI

/// 사용자가 저장하는 커맨드 카드.
struct SavedCommand: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var text: String
}

/// 카드 리스트 + JSON 파일 영속화. 앱 재실행해도 유지.
@Observable
final class CommandStore {
  var commands: [SavedCommand] = []

  private let fileURL: URL

  init() {
    // 저장 위치는 이 소스 파일 기준 프로젝트 루트(MyTerm/) 안 commands.json.
    // #filePath = .../MyTerm/Sources/MyTerm/Command.swift → 세 단계 위가 MyTerm/.
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()  // Sources/MyTerm
      .deletingLastPathComponent()  // Sources
      .deletingLastPathComponent()  // MyTerm
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("commands.json")
    load()
  }

  func add(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    commands.append(SavedCommand(text: trimmed))
    save()
  }

  func remove(_ id: UUID) {
    commands.removeAll { $0.id == id }
    save()
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let list = try? JSONDecoder().decode([SavedCommand].self, from: data)
    else { return }
    commands = list
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(commands) else { return }
    try? data.write(to: fileURL)
  }
}
