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
  /// 카드 드롭 명령은 `__cust_run '<cmd>'` 로 감싸서 보내므로,
  /// 훅에서는 실제 사용자 명령 문자열을 별도 변수로 받는다.
  /// 앱 내부 초기화 명령은 히스토리에 잡히지 않도록 필터.
  func zshAppendHookScript() -> String {
    let path = shellQuote(logURL.path)
    let script = """
    __cust_hist_log=\(path); \
    __cust_hist_skip() { local c=${1##[[:space:]]#}; \
      case "$c" in \
        source*|*__cust_*|clear|clear*|rm\\ -f*|rm*/CusTerminal-hooks/*|history|autoload*|add-zsh-hook*) return 0 ;; \
      esac; \
      return 1; \
    }; \
    __cust_hist_pre() { \
      if __cust_hist_skip "$1"; then __cust_hist_last=''; return; fi; \
      __cust_hist_last=$1; \
      printf 'PRE\\t%d\\t%s\\n' "$EPOCHSECONDS" "$1" >> "$__cust_hist_log"; \
    }; \
    __cust_hist_post() { local __e=$?; \
      [ -z "$__cust_hist_last" ] && return; \
      printf 'POST\\t%d\\t%d\\t%s\\n' "$EPOCHSECONDS" "$__e" "$PWD" >> "$__cust_hist_log"; \
      __cust_hist_last=''; \
    }; \
    autoload -Uz add-zsh-hook 2>/dev/null; \
    add-zsh-hook -d preexec __cust_hist_pre 2>/dev/null; \
    add-zsh-hook -d precmd __cust_hist_post 2>/dev/null; \
    add-zsh-hook preexec __cust_hist_pre; \
    add-zsh-hook precmd __cust_hist_post
    """
    return " " + script + "\n"
  }

  // 참고: 이전에 __cust_run 으로 감싸서 출력을 캡처하던 로직은 제거됨.
  // 드롭 == 타이핑 로 통일하기 위해 TerminalPane 에서 명령 텍스트만 send.
  // 타이핑과 동일하게 zsh preexec/precmd 훅이 히스토리를 처리한다.

  private func shellQuote(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
  }
}
