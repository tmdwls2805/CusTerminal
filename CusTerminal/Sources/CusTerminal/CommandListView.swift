import SwiftUI

/// 왼쪽 사이드바: 입력창 + 저장된 커맨드 카드 리스트 + 하단 설정 진입.
struct CommandListView: View {
  @Bindable var store: CommandStore
  @State private var input: String = ""
  @State private var settingsExpanded: Bool = true

  var body: some View {
    VStack(spacing: 8) {
      // 상단 사용법 안내 (상시 표시).
      HStack(spacing: 6) {
        Image(systemName: "hand.point.up.left.fill")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
        Text("카드를 pane 위로 드래그 → 그 pane 에서 실행")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)

      // 입력창: enter 로 저장.
      HStack {
        TextField("자주 쓰는 명령 (예: docker ps)", text: $input, onCommit: submit)
          .textFieldStyle(.roundedBorder)
        Button("저장", action: submit)
      }
      .padding(.horizontal)

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

      // 하단 설정: 헤더 클릭으로 접기/펴기.
      // 카드 리스트와 시각적으로 구분되도록 위쪽에 얇은 구분선.
      VStack(spacing: 6) {
        Divider()
        Button {
          withAnimation(.easeInOut(duration: 0.18)) { settingsExpanded.toggle() }
        } label: {
          HStack(spacing: 6) {
            // 펼침(아래로 열림) → chevron.down, 접힘(위로 닫힘) → chevron.up
            // 사용자의 시각적 기대와 화살표 방향을 맞춤.
            Image(systemName: settingsExpanded ? "chevron.down" : "chevron.up")
              .font(.system(size: 10, weight: .semibold))
              .rotationEffect(.degrees(0))
            Text("설정")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
            Spacer()
          }
          .contentShape(Rectangle())
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
        }
        .buttonStyle(.plain)

        if settingsExpanded {
          VStack(spacing: 6) {
            ThemePickerButton()
            FontPickerButton()
            BackgroundPickerButton()
            SeparatorPickerButton()
            PetPickerButton()
          }
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
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
        // 명령이 길어 잘려도 hover 시 전체가 툴팁으로 나오게.
        .tooltip(command.text)
      Spacer()
      Button(action: onDelete) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .tooltip("이 카드 삭제")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    // 카드 자체 툴팁은 명령 텍스트만 (사용법 안내는 사이드바 상단에 상시 표시).
    // 드래그 소스: 카드 텍스트를 plain text 로 전달. TerminalPane 이 drop 해서 실행.
    .onDrag { NSItemProvider(object: command.text as NSString) }
  }
}
