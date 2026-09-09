import SwiftUI

/// 왼쪽 사이드바: 입력창 + 저장된 커맨드 카드 리스트.
/// 카드는 드래그 소스이며 옆 x 버튼으로 삭제 가능.
struct CommandListView: View {
  @Bindable var store: CommandStore
  @State private var input: String = ""

  var body: some View {
    VStack(spacing: 8) {
      // 입력창: enter 로 저장.
      HStack {
        TextField("자주 쓰는 명령 (예: docker ps)", text: $input, onCommit: submit)
          .textFieldStyle(.roundedBorder)
        Button("저장", action: submit)
      }
      .padding(.horizontal)
      .padding(.top, 8)

      // 카드 리스트.
      ScrollView {
        VStack(spacing: 4) {
          ForEach(store.commands) { cmd in
            CommandCardRow(command: cmd, onDelete: { store.remove(cmd.id) })
          }
        }
        .padding(.horizontal)
      }

      Spacer(minLength: 0)

      // 하단: 테마 · 폰트 · 배경 · 구분선 진입 버튼.
      VStack(spacing: 6) {
        ThemePickerButton()
        FontPickerButton()
        BackgroundPickerButton()
        SeparatorPickerButton()
      }
      .padding(.horizontal)
      .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func submit() {
    store.add(input)
    input = ""
  }
}

private struct CommandCardRow: View {
  let command: SavedCommand
  let onDelete: () -> Void

  var body: some View {
    HStack {
      Text(command.text)
        .font(.system(.body, design: .monospaced))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Button(action: onDelete) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    // 드래그 소스: 카드 텍스트를 plain text 로 전달. TerminalPane 이 drop 해서 실행.
    .onDrag { NSItemProvider(object: command.text as NSString) }
  }
}
