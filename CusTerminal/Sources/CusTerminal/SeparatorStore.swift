import Foundation
import SwiftUI

/// 카드 실행 시 앞뒤에 붙는 구분선 설정.
/// 전역 하나만 (세션별 필요성 낮음). separator.json 에 영속화.
@Observable
final class SeparatorStore {
  /// 기본값은 꺼짐. 사용자가 팝오버에서 "적용하기" 를 켜야 카드 실행 시 구분선 붙음.
  var enabled: Bool = false {
    didSet { if oldValue != enabled { save() } }
  }
  /// 시작 라인 반복 문자.
  var startChar: String = "=" {
    didSet { if oldValue != startChar { save() } }
  }
  /// 끝 라인 반복 문자.
  var endChar: String = "-" {
    didSet { if oldValue != endChar { save() } }
  }
  /// 시작 라벨 템플릿 (`{cmd}` 치환). 비면 라벨 없음.
  var startLabel: String = "▶ {cmd}" {
    didSet { if oldValue != startLabel { save() } }
  }
  /// 끝 라벨 템플릿. 비면 라벨 없음.
  var endLabel: String = "done" {
    didSet { if oldValue != endLabel { save() } }
  }
  /// 라벨 양쪽 문자 반복 개수 (한쪽 기준).
  var padCount: Int = 8 {
    didSet { if oldValue != padCount { save() } }
  }

  private let fileURL: URL

  init() {
    let source = URL(fileURLWithPath: #filePath)
    let dir = source
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    self.fileURL = dir.appendingPathComponent("separator.json")
    load()
  }

  /// zsh preexec/precmd hook 을 등록해서
  /// 이후 어떤 명령이든(타이핑/드롭) 앞뒤에 구분선이 자동으로 출력되게 한다.
  /// - 반환: 셸에 그대로 보낼 초기화 스크립트 (한 줄, 앞 공백 = 히스토리 제외).
  func zshHookScript() -> String {
    // 라벨/문자에서 사용자가 넣은 홑따옴표는 이스케이프.
    let ch1 = shellQuote(String(startChar.prefix(1).isEmpty ? "=" : startChar.prefix(1)))
    let ch2 = shellQuote(String(endChar.prefix(1).isEmpty ? "-" : endChar.prefix(1)))
    let startTpl = shellQuote(startLabel)     // "▶ {cmd}"
    let endTpl = shellQuote(endLabel)         // "done"
    let padArg = String(padCount)

    // zsh 함수 정의 + hook 등록. 세미콜론으로 한 줄에 이어붙임.
    // preexec 는 $1 에 실행될 명령 문자열을 받음.
    let script = """
    __cust_start_char=\(ch1); __cust_end_char=\(ch2); \
    __cust_start_tpl=\(startTpl); __cust_end_tpl=\(endTpl); __cust_pad=\(padArg); \
    __cust_line() { local ch=$1 tpl=$2 cmd=$3 pad; \
      pad=$(printf '%.0s'"$ch" $(seq 1 "$__cust_pad")); \
      local label=${tpl//\\{cmd\\}/$cmd}; \
      if [ -z "${label// /}" ]; then \
        printf '%.0s'"$ch" $(seq 1 $(( __cust_pad * 2 + 4 ))); echo; \
      else \
        printf '%s %s %s\\n' "$pad" "$label" "$pad"; \
      fi; \
    }; \
    __cust_pre() { __cust_line "$__cust_start_char" "$__cust_start_tpl" "$1"; }; \
    __cust_post() { __cust_line "$__cust_end_char" "$__cust_end_tpl" ''; }; \
    autoload -Uz add-zsh-hook 2>/dev/null; \
    add-zsh-hook -d preexec __cust_pre 2>/dev/null; \
    add-zsh-hook -d precmd __cust_post 2>/dev/null; \
    add-zsh-hook preexec __cust_pre; \
    add-zsh-hook precmd __cust_post
    """
    return " " + script + "\n"
  }

  /// hook 제거 (enabled = false 로 바뀔 때).
  func zshHookDisableScript() -> String {
    return " autoload -Uz add-zsh-hook 2>/dev/null; add-zsh-hook -d preexec __cust_pre 2>/dev/null; add-zsh-hook -d precmd __cust_post 2>/dev/null\n"
  }

  /// 실제 셸에 결합해서 보낼 명령 라인 배열.
  /// TerminalPane 이 "; " 로 이어붙여 한 줄로 send.
  func linesFor(command: String) -> [String] {
    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    guard enabled else { return [trimmed] }

    var out: [String] = []
    if let s = buildLine(char: startChar, template: startLabel, cmd: trimmed) {
      out.append("printf '%s\\n' \(shellQuote(s))")
    }
    out.append(trimmed)
    if let e = buildLine(char: endChar, template: endLabel, cmd: trimmed) {
      out.append("printf '%s\\n' \(shellQuote(e))")
    }
    return out
  }

  /// 미리보기용 (셸 quoting 없이 사용자에게 그대로 보여줄 수 있는 두 줄 예시).
  func previewLines(for command: String) -> [String] {
    var lines: [String] = []
    if enabled {
      if let s = buildLine(char: startChar, template: startLabel, cmd: command) { lines.append(s) }
      lines.append(command)
      if let e = buildLine(char: endChar, template: endLabel, cmd: command) { lines.append(e) }
    } else {
      lines.append(command)
    }
    return lines
  }

  /// TerminalPane 이 직접 화면에 그릴 때 쓰는 public 진입점.
  func buildLinePublic(char: String, template: String, cmd: String) -> String? {
    buildLine(char: char, template: template, cmd: cmd)
  }

  private func buildLine(char: String, template: String, cmd: String) -> String? {
    let ch = char.isEmpty ? "=" : String(char.prefix(1))
    let label = template.replacingOccurrences(of: "{cmd}", with: cmd)
    let pad = String(repeating: ch, count: max(0, padCount))
    if label.trimmingCharacters(in: .whitespaces).isEmpty {
      // 라벨 없으면 그냥 긴 라인 (padCount * 2 + 최소 라벨 자리).
      let full = String(repeating: ch, count: max(4, padCount * 2 + 4))
      return full
    }
    return "\(pad) \(label) \(pad)"
  }

  private func shellQuote(_ s: String) -> String {
    // 홑따옴표 안 홑따옴표는 '\'' 로 escape.
    let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
  }

  // MARK: 영속화

  private struct Persisted: Codable {
    var enabled: Bool
    var startChar: String
    var endChar: String
    var startLabel: String
    var endLabel: String
    var padCount: Int
  }

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let p = try? JSONDecoder().decode(Persisted.self, from: data)
    else { return }
    enabled = p.enabled
    startChar = p.startChar
    endChar = p.endChar
    startLabel = p.startLabel
    endLabel = p.endLabel
    padCount = p.padCount
  }

  private func save() {
    let p = Persisted(enabled: enabled, startChar: startChar, endChar: endChar,
                      startLabel: startLabel, endLabel: endLabel, padCount: padCount)
    guard let data = try? JSONEncoder().encode(p) else { return }
    try? data.write(to: fileURL)
  }
}
