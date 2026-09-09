import Foundation
import SwiftUI

/// 한 pane 에서 실행된 명령 하나.
struct HistoryEntry: Identifiable, Equatable {
  let id: UUID = UUID()
  let time: Date
  let command: String
  /// 명령 완료 시 채워짐. nil = 아직 실행 중 or 정보 없음.
  var durationSeconds: Int? = nil
  var exitCode: Int? = nil
  var cwd: String? = nil
  /// 카드 드롭으로 실행된 경우에만 stdout+stderr 텍스트가 담김.
  /// 타이핑 명령은 zsh 훅 만으로 잡을 수 없어서 nil.
  var output: String? = nil
}

/// pane 별 히스토리. zsh preexec hook 이 각 명령을 임시 파일에 append 하고
/// 앱이 그 파일을 watch 해서 실시간으로 목록 갱신한다.
final class HistoryStore: ObservableObject {
  @Published var entries: [HistoryEntry] = []
  let logURL: URL

  private var source: DispatchSourceFileSystemObject?
  private var fileHandle: FileHandle?
  private var readOffset: UInt64 = 0

  init() {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CusTerminal-history", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    self.logURL = dir.appendingPathComponent("pane-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    startWatching()
  }

  deinit {
    source?.cancel()
    try? fileHandle?.close()
    try? FileManager.default.removeItem(at: logURL)
  }

  // MARK: - 파일 watch

  private func startWatching() {
    guard let handle = try? FileHandle(forReadingFrom: logURL) else { return }
    self.fileHandle = handle
    let s = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: handle.fileDescriptor,
      eventMask: [.extend, .write, .delete],
      queue: .main
    )
    s.setEventHandler { [weak self] in
      guard let self else { return }
      self.readNewLines()
    }
    s.resume()
    self.source = s
  }

  private func readNewLines() {
    guard let handle = fileHandle else { return }
    do {
      try handle.seek(toOffset: readOffset)
    } catch { return }
    let data = handle.availableData
    guard !data.isEmpty else { return }
    readOffset += UInt64(data.count)
    guard let chunk = String(data: data, encoding: .utf8) else { return }
    for line in chunk.split(separator: "\n") {
      parse(line: String(line))
    }
    // 너무 커지지 않게 최근 500개만.
    if entries.count > 500 {
      entries.removeFirst(entries.count - 500)
    }
  }

  /// 3가지 라인 프로토콜 지원:
  /// - `PRE\t<ts>\t<cmd>`     : 명령 시작 (새 entry)
  /// - `POST\t<ts>\t<exit>\t<cwd>` : 마지막 entry 에 완료 정보 채움
  /// - `OUT\t<base64>`        : 마지막 entry 의 output (append)
  private func parse(line: String) {
    let parts = line.components(separatedBy: "\t")
    guard let kind = parts.first else { return }
    switch kind {
    case "PRE":
      guard parts.count >= 3, let ts = TimeInterval(parts[1]) else { return }
      let cmd = parts.dropFirst(2).joined(separator: "\t")
      entries.append(HistoryEntry(time: Date(timeIntervalSince1970: ts), command: cmd))
    case "POST":
      guard parts.count >= 4, let ts = TimeInterval(parts[1]), let exit = Int(parts[2]),
            var last = entries.last else { return }
      let cwd = parts[3]
      last.durationSeconds = max(0, Int(ts - last.time.timeIntervalSince1970))
      last.exitCode = exit
      last.cwd = cwd
      entries[entries.count - 1] = last
    case "OUT":
      guard parts.count >= 2, var last = entries.last,
            let data = Data(base64Encoded: parts[1]),
            let text = String(data: data, encoding: .utf8) else { return }
      last.output = (last.output ?? "") + text
      entries[entries.count - 1] = last
    default:
      break
    }
  }

  /// zsh 훅 스크립트: preexec 로 PRE 라인, precmd 로 POST 라인 append.
  func zshAppendHookScript() -> String {
    let path = shellQuote(logURL.path)
    let script = """
    __cust_hist_log=\(path); \
    __cust_hist_pre() { printf 'PRE\\t%d\\t%s\\n' "$EPOCHSECONDS" "$1" >> "$__cust_hist_log"; }; \
    __cust_hist_post() { local __e=$?; printf 'POST\\t%d\\t%d\\t%s\\n' "$EPOCHSECONDS" "$__e" "$PWD" >> "$__cust_hist_log"; }; \
    autoload -Uz add-zsh-hook 2>/dev/null; \
    add-zsh-hook -d preexec __cust_hist_pre 2>/dev/null; \
    add-zsh-hook -d precmd __cust_hist_post 2>/dev/null; \
    add-zsh-hook preexec __cust_hist_pre; \
    add-zsh-hook precmd __cust_hist_post
    """
    return " " + script + "\n"
  }

  /// 카드 드롭 실행 명령을 감쌀 때, stdout+stderr 를 base64 로 로그에 함께 기록.
  /// 사용자에겐 원래대로 화면에 출력 + 히스토리에는 OUT 라인 추가.
  /// 반환: 셸에 send 할 한 줄.
  func wrapCommandCapturingOutput(_ command: String) -> String {
    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "\n" }
    let logPath = shellQuote(logURL.path)
    // tee 로 화면과 파일에 동시 출력 → 파일 내용을 base64 로 감싸 OUT 라인 추가.
    // 임시 파일 → base64 → 로그에 append.
    let tmpVar = "__cust_out_$$"
    let wrapped = """
     __\(tmpVar)=$(mktemp -t custout) && { \(trimmed); } 2>&1 | tee "$__\(tmpVar)"; \
    printf 'OUT\\t%s\\n' "$(base64 < "$__\(tmpVar)" | tr -d '\\n')" >> \(logPath); \
    rm -f "$__\(tmpVar)"
    """
    return wrapped + "\n"
  }

  private func shellQuote(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
  }
}
