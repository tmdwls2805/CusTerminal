import Foundation

/// 디버깅용 파일 로거. /tmp/custerminal-debug.log 에 append.
/// tail -f /tmp/custerminal-debug.log 로 실시간 확인.
enum Log {
  static let url = URL(fileURLWithPath: "/tmp/custerminal-debug.log")
  private static let lock = NSLock()

  static func write(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    let ts = DateFormatter.iso.string(from: Date())
    let line = "[\(ts)] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: url.path) {
      try? "".data(using: .utf8)?.write(to: url)
    }
    if let handle = try? FileHandle(forWritingTo: url) {
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
      try? handle.close()
    }
  }
}

private extension DateFormatter {
  static let iso: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
  }()
}
