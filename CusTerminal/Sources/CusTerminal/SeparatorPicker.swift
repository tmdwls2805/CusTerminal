import SwiftUI

/// 사이드바 하단 진입 버튼.
struct SeparatorPickerButton: View {
  @Environment(SeparatorStore.self) private var sepStore
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: sepStore.enabled ? "text.append" : "text.append")
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 0) {
          Text("구분선").font(.system(size: 12))
          Text(sepStore.enabled
               ? "\(sepStore.startChar) … \(sepStore.endChar)"
               : "꺼짐")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $show, arrowEdge: .top) {
      SeparatorPickerPopover()
    }
    .help("카드 실행 시 구분선 설정")
  }
}

struct SeparatorPickerPopover: View {
  @Environment(SeparatorStore.self) private var sepStore

  var body: some View {
    @Bindable var s = sepStore
    VStack(alignment: .leading, spacing: 12) {
      Toggle("적용하기 (카드 실행 앞뒤에 구분선 삽입)", isOn: $s.enabled)
        .font(.subheadline)

      Group {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
          GridRow {
            Text("시작 문자").frame(width: 90, alignment: .leading)
            SingleCharField(text: $s.startChar)
          }
          GridRow {
            Text("끝 문자").frame(width: 90, alignment: .leading)
            SingleCharField(text: $s.endChar)
          }
          GridRow {
            Text("시작 라벨").frame(width: 90, alignment: .leading)
            TextField("{cmd} 로 명령 치환", text: $s.startLabel)
              .textFieldStyle(.roundedBorder)
          }
          GridRow {
            Text("끝 라벨").frame(width: 90, alignment: .leading)
            TextField("비우면 라벨 없음", text: $s.endLabel)
              .textFieldStyle(.roundedBorder)
          }
          GridRow {
            Text("양쪽 반복").frame(width: 90, alignment: .leading)
            Stepper(value: $s.padCount, in: 2...40) {
              Text("\(s.padCount) 자").monospacedDigit()
            }
          }
        }
        .disabled(!s.enabled)
        .opacity(s.enabled ? 1 : 0.5)
      }

      Divider()
      Text("미리보기").font(.caption).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        ForEach(sepStore.previewLines(for: "docker ps"), id: \.self) { line in
          Text(line)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(8)
      .background(Color.black.cornerRadius(6))

      HStack {
        Button {
          // 기본값 = 꺼짐 + 표준 값.
          s.enabled = false
          s.startChar = "="
          s.endChar = "-"
          s.startLabel = "▶ {cmd}"
          s.endLabel = "done"
          s.padCount = 8
        } label: {
          Label("기본값으로", systemImage: "arrow.uturn.backward")
            .font(.caption)
        }
        .buttonStyle(.borderless)
        Spacer()
      }
    }
    .padding(14)
    .frame(width: 380)
  }
}

/// 한 글자만 입력받는 필드. 여러 자 넣으면 첫 글자만.
private struct SingleCharField: View {
  @Binding var text: String

  var body: some View {
    TextField("", text: Binding(
      get: { text },
      set: { new in
        text = String(new.prefix(1))
      }
    ))
    .textFieldStyle(.roundedBorder)
    .frame(width: 44)
    .multilineTextAlignment(.center)
    .monospaced()
  }
}
