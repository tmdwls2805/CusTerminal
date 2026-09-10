import Foundation
import SwiftUI

/// 사용자가 저장하는 커맨드 카드.
struct SavedCommand: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var text: String
  /// 소속 폴더 ID. nil = "미분류".
  var folderID: UUID? = nil
}

/// 카드를 담는 폴더.
struct CommandFolder: Identifiable, Codable, Equatable {
  var id: UUID = UUID()
  var name: String
  /// 접혀있는지 (기본 = 펼침).
  var collapsed: Bool = false
}

/// 카드 리스트 + 폴더 + JSON 파일 영속화.
@Observable
final class CommandStore {
  var commands: [SavedCommand] = []
  var folders: [CommandFolder] = []

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.fileURL = dir.appendingPathComponent("commands.json")
    load()
  }

  // MARK: - 커맨드

  func add(_ text: String, folderID: UUID? = nil) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    commands.append(SavedCommand(text: trimmed, folderID: folderID))
    save()
  }

  func remove(_ id: UUID) {
    commands.removeAll { $0.id == id }
    save()
  }

  func move(_ id: UUID, to folderID: UUID?) {
    guard let idx = commands.firstIndex(where: { $0.id == id }) else { return }
    commands[idx].folderID = folderID
    save()
  }

  func commands(in folderID: UUID?) -> [SavedCommand] {
    commands.filter { $0.folderID == folderID }
  }

  // MARK: - 폴더

  @discardableResult
  func addFolder(name: String = "새 폴더") -> CommandFolder {
    let f = CommandFolder(name: name)
    folders.append(f)
    save()
    return f
  }

  func renameFolder(_ id: UUID, to name: String) {
    guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
    folders[idx].name = name
    save()
  }

  /// 폴더 삭제.
  /// - deleteCommands=true: 안 카드도 함께 삭제
  /// - deleteCommands=false: 카드는 미분류로 이동
  func removeFolder(_ id: UUID, deleteCommands: Bool) {
    if deleteCommands {
      commands.removeAll { $0.folderID == id }
    } else {
      for i in commands.indices where commands[i].folderID == id {
        commands[i].folderID = nil
      }
    }
    folders.removeAll { $0.id == id }
    save()
  }

  func toggleCollapsed(_ id: UUID) {
    guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
    folders[idx].collapsed.toggle()
    save()
  }

  /// 폴더 순서 이동. sourceID 를 targetID 앞(before=true) 또는 뒤에 삽입.
  func reorderFolder(source: UUID, target: UUID, before: Bool) {
    guard source != target,
          let srcIdx = folders.firstIndex(where: { $0.id == source })
    else { return }
    let moving = folders.remove(at: srcIdx)
    guard let dstIdx = folders.firstIndex(where: { $0.id == target }) else {
      folders.append(moving)
      save()
      return
    }
    folders.insert(moving, at: before ? dstIdx : dstIdx + 1)
    save()
  }

  // MARK: - 영속화

  /// v2 포맷: { commands, folders }.  v1 (배열 only) 도 호환 로드.
  private struct Persisted: Codable {
    var commands: [SavedCommand]
    var folders: [CommandFolder]
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL) else { return }
    // v2 시도.
    if let p = try? JSONDecoder().decode(Persisted.self, from: data) {
      commands = p.commands
      folders = p.folders
      return
    }
    // v1 fallback (배열 only).
    if let list = try? JSONDecoder().decode([SavedCommand].self, from: data) {
      commands = list
      folders = []
    }
  }

  private func save() {
    let p = Persisted(commands: commands, folders: folders)
    guard let data = try? JSONEncoder().encode(p) else { return }
    try? data.write(to: fileURL)
  }
}
