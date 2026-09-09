import SwiftUI

/// 사이드바 하단 진입 버튼.
struct SeparatorPickerButton: View {
  @Environment(SeparatorStore.self) private var sepStore
  @Environment(DropRunStore.self) private var dropRunStore
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "text.append")
          .foregroundStyle(sepStore.enabled ? Color.accentColor : .secondary)
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 4) {
            Text("구분선").font(.system(size: 12))
            // 켜짐/꺼짐 뱃지: 컬러로 즉시 구분되게.
            Text(sepStore.enabled ? "ON" : "OFF")
              .font(.system(size: 9, weight: .bold))
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(
                Capsule().fill(sepStore.enabled
                               ? Color.accentColor.opacity(0.9)
                               : Color.gray.opacity(0.35))
              )
              .foregroundColor(sepStore.enabled ? .white : .primary)
          }
          Text(sepStore.enabled
               ? "\(sepStore.startChar) … \(sepStore.endChar) · 드롭 \(dropRunStore.autoRun ? "자동실행" : "텍스트만")"
               : "드롭 \(dropRunStore.autoRun ? "자동실행" : "텍스트만")")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
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
    .tooltip("카드 드래그 & 드롭 동작 (텍스트만 얹기 vs 자동 실행) + 명령 앞뒤 구분선 표시 설정")
  }
}

struct SeparatorPickerPopover: View {
  @Environment(SeparatorStore.self) private var sepStore
  @Environment(DropRunStore.self) private var dropRunStore

  var body: some View {
    @Bindable var s = sepStore
    @Bindable var d = dropRunStore
    VStack(alignment: .leading, spacing: 12) {
      // 드롭 실행 방식 (구분선과 독립).
      VStack(alignment: .leading, spacing: 4) {
        Text("카드 드래그 & 드롭 동작")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
        Toggle(isOn: $d.autoRun) {
          Text(d.autoRun
               ? "바로 실행 (엔터까지 자동)"
               : "텍스트만 얹기 (엔터는 직접) — 기본")
            .font(.subheadline)
        }
      }
      .padding(10)
      .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))

      Divider()

      // 구분선 옵션.
      HStack(spacing: 8) {
        Toggle("구분선 표시", isOn: $s.enabled)
          .font(.subheadline)
          .toggleStyle(.switch)
        Text(s.enabled ? "ON" : "OFF")
          .font(.system(size: 10, weight: .bold))
          .padding(.horizontal, 6).padding(.vertical, 2)
          .background(Capsule().fill(s.enabled
                                     ? Color.accentColor.opacity(0.9)
                                     : Color.gray.opacity(0.35)))
          .foregroundColor(s.enabled ? .white : .primary)
        Spacer()
      }

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
