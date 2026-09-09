import SwiftUI

/// pane 헤더에 붙는 히스토리 버튼 + 팝오버.
struct PaneHistoryButton: View {
  @ObservedObject var session: TerminalSession
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      Image(systemName: "clock.arrow.circlepath")
        .frame(width: 18, height: 16)
    }
    .buttonStyle(.borderless)
    .help("이 pane 의 명령 히스토리 (시간 순)")
    .popover(isPresented: $show, arrowEdge: .bottom) {
      HistoryPopoverContent(session: session)
    }
  }
}

private struct HistoryPopoverContent: View {
  @ObservedObject var session: TerminalSession
  @ObservedObject var history: HistoryStore
  @State private var query: String = ""
  @State private var newestFirst: Bool = true

  init(session: TerminalSession) {
    self.session = session
    self.history = session.history
  }

  private var filtered: [HistoryEntry] {
    let base = newestFirst ? history.entries.reversed() : Array(history.entries)
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return Array(base) }
    return base.filter { $0.command.lowercased().contains(q) }
  }

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM/dd HH:mm:ss"
    return f
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("명령 히스토리").font(.headline)
        Spacer()
        Text("\(history.entries.count) 개")
          .font(.caption).foregroundStyle(.secondary)
      }

      HStack(spacing: 6) {
        TextField("검색 (텍스트 포함)", text: $query)
          .textFieldStyle(.roundedBorder)
        Picker("", selection: $newestFirst) {
          Text("최신↑").tag(true)
          Text("오래된↑").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }

      if filtered.isEmpty {
        VStack(spacing: 4) {
          Image(systemName: "clock").font(.title2).foregroundStyle(.tertiary)
          Text(history.entries.isEmpty
               ? "아직 실행한 명령이 없어요"
               : "검색 결과 없음")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(filtered) { entry in
              HistoryRow(
                entry: entry,
                onRerun: {
                  session.holder.send(text: entry.command + "\n")
                },
                onCopy: {
                  let pb = NSPasteboard.general
                  pb.declareTypes([.string], owner: nil)
                  pb.setString(entry.command, forType: .string)
                }
              )
            }
          }
          .padding(.vertical, 2)
        }
        .frame(width: 460, height: 320)
      }
    }
    .padding(14)
    .frame(width: 480)
  }
}

private struct HistoryRow: View {
  let entry: HistoryEntry
  let onRerun: () -> Void
  let onCopy: () -> Void
  @State private var expanded: Bool = false

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM/dd HH:mm:ss"
    return f
  }()

  /// 접었을 때도 정보가 뭔가 담겨있음을 알리기 위한 뱃지 (종료코드/시간/CWD/출력).
  private var hasDetails: Bool {
    entry.exitCode != nil || entry.durationSeconds != nil || entry.cwd != nil || entry.output != nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top, spacing: 8) {
        Button {
          expanded.toggle()
        } label: {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10))
            .foregroundStyle(hasDetails ? .primary : .tertiary)
            .frame(width: 14)
        }
        .buttonStyle(.borderless)
        .disabled(!hasDetails)

        Text(HistoryRow.timeFormatter.string(from: entry.time))
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.tertiary)
          .frame(width: 110, alignment: .leading)

        VStack(alignment: .leading, spacing: 0) {
          Text(entry.command)
            .font(.system(size: 12, design: .monospaced))
            .lineLimit(2)
            .truncationMode(.middle)
          if let exit = entry.exitCode {
            HStack(spacing: 6) {
              Text(exit == 0 ? "✓" : "✗ \(exit)")
                .foregroundColor(exit == 0 ? .green : .red)
                .font(.system(size: 10, weight: .semibold))
              if let d = entry.durationSeconds {
                Text("\(d)s").font(.system(size: 10)).foregroundStyle(.secondary)
              }
              if entry.output != nil {
                Text("out").font(.system(size: 9)).foregroundStyle(.blue.opacity(0.8))
              }
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button(action: onRerun) {
          Image(systemName: "play.fill").font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .help("이 pane 에서 다시 실행")
        Button(action: onCopy) {
          Image(systemName: "doc.on.doc").font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .help("클립보드에 복사")
      }

      if expanded {
        VStack(alignment: .leading, spacing: 3) {
          if let cwd = entry.cwd {
            Text("CWD: \(cwd)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
          }
          if let d = entry.durationSeconds {
            Text("소요: \(d) 초").font(.system(size: 10)).foregroundStyle(.secondary)
          }
          if let e = entry.exitCode {
            Text("종료 코드: \(e)").font(.system(size: 10)).foregroundStyle(.secondary)
          }
          if let out = entry.output, !out.isEmpty {
            Divider()
            Text("출력")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.secondary)
            ScrollView {
              Text(out)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .frame(maxHeight: 180)
            .padding(6)
            .background(Color.black.opacity(0.85).cornerRadius(4))
            .foregroundColor(.white)
          } else if entry.exitCode != nil {
            Text("출력 캡처 없음 (타이핑 명령은 출력이 히스토리에 저장되지 않음)")
              .font(.system(size: 10)).foregroundStyle(.tertiary).italic()
          }
        }
        .padding(.leading, 24)
        .padding(.trailing, 6)
        .padding(.top, 2)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .contextMenu {
      Button("다시 실행", action: onRerun)
      Button("복사", action: onCopy)
      if entry.output != nil {
        Button(expanded ? "결과 접기" : "결과 펼치기") { expanded.toggle() }
      }
    }
  }
}
