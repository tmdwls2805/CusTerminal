import SwiftUI
import AppKit

/// 사이드바 하단 폰트 진입 버튼.
struct FontPickerButton: View {
  @Environment(FontStore.self) private var fontStore
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "textformat")
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 0) {
          Text(fontStore.globalFont.name)
            .font(.system(size: 12))
            .lineLimit(1)
          Text("\(Int(fontStore.globalFont.size))pt")
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
      FontPickerPopover()
    }
    .help("폰트 종류 · 크기 설정")
  }
}

/// 폰트 팝오버: 모드 토글 + 폰트 리스트 + 크기 stepper + 미리보기.
struct FontPickerPopover: View {
  @Environment(FontStore.self) private var fontStore
  @Environment(\.currentLayoutStore) private var currentLayout

  var body: some View {
    @Bindable var store = fontStore
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("폰트").font(.headline)
        Spacer()
        Picker("", selection: $store.mode) {
          Text("전역").tag(FontMode.global)
          Text("세션별").tag(FontMode.perPane)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }

      Text(store.mode == .global
           ? "선택한 폰트가 모든 pane 에 즉시 적용됩니다."
           : "선택한 폰트가 전역 기본으로 저장되고, 각 pane 은 헤더의 폰트 버튼으로 개별 지정할 수 있습니다.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      // 크기 조절: 입력 필드 + Stepper 병행.
      HStack(spacing: 6) {
        Text("크기")
        FontSizeField(size: Binding(
          get: { store.globalFont.size },
          set: { store.globalFont.size = $0 }
        ))
        Text("pt").foregroundStyle(.secondary)
        Stepper("", value: Binding(
          get: { store.globalFont.size },
          set: { store.globalFont.size = $0 }
        ), in: 6...72, step: 1)
        .labelsHidden()
      }

      // 폰트 목록.
      List(selection: Binding(
        get: { store.globalFont.name },
        set: { new in if let new { store.globalFont.name = new } }
      )) {
        ForEach(FontCatalog.monospaced, id: \.self) { family in
          Text(family)
            .font(.custom(family, size: 13))
            .tag(family as String?)
        }
      }
      .frame(width: 320, height: 220)

      // 미리보기.
      Text("silverslab@Mac ~ %  ls -la")
        .font(.custom(store.globalFont.name, size: store.globalFont.size))
        .foregroundColor(.white)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.cornerRadius(6))

      Divider()
      HStack {
        Button {
          fontStore.resetToDefaults(sessions: currentLayout?.allSessions ?? [])
        } label: {
          Label("기본값으로 되돌리기", systemImage: "arrow.uturn.backward")
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .help("전역 모드 · Menlo 12pt 로 리셋 + 모든 pane 개별 폰트 제거")
        Spacer()
      }
    }
    .padding(14)
    .frame(width: 340)
  }
}

/// 정수 폰트 크기 입력 필드. 6~72 범위 clamp. Enter 또는 focus 해제 시 반영.
struct FontSizeField: View {
  @Binding var size: CGFloat
  @State private var text: String = ""
  @FocusState private var focused: Bool

  private let minSize: CGFloat = 6
  private let maxSize: CGFloat = 72

  var body: some View {
    TextField("", text: $text)
      .textFieldStyle(.roundedBorder)
      .frame(width: 44)
      .multilineTextAlignment(.center)
      .monospacedDigit()
      .focused($focused)
      .onSubmit(commit)
      .onChange(of: focused) { _, isFocused in
        if !isFocused { commit() }
      }
      .onChange(of: size) { _, new in
        // 외부에서 바뀌면 (예: stepper) 표시 갱신.
        let display = String(Int(new))
        if text != display { text = display }
      }
      .onAppear { text = String(Int(size)) }
  }

  private func commit() {
    let cleaned = text.trimmingCharacters(in: .whitespaces)
    if let v = Double(cleaned) {
      let clamped = min(max(CGFloat(v), minSize), maxSize)
      size = clamped
      text = String(Int(clamped))
    } else {
      // 파싱 실패 → 기존 값 되돌리기.
      text = String(Int(size))
    }
  }
}

/// pane 헤더용 세션-폰트 버튼 (perPane 모드).
struct SessionFontButton: View {
  @Environment(FontStore.self) private var fontStore
  @ObservedObject var session: TerminalSession
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      Image(systemName: "textformat")
        .frame(width: 18, height: 16)
    }
    .buttonStyle(.borderless)
    .help("이 pane 의 폰트 (세션별 모드)")
    .popover(isPresented: $show, arrowEdge: .bottom) {
      SessionFontEditor(session: session)
    }
  }
}

private struct SessionFontEditor: View {
  @Environment(FontStore.self) private var fontStore
  @ObservedObject var session: TerminalSession

  private var effective: TerminalFontChoice {
    session.fontOverride ?? fontStore.globalFont
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("이 pane 의 폰트").font(.headline)

      HStack(spacing: 6) {
        Text("크기")
        FontSizeField(size: Binding(
          get: { effective.size },
          set: { new in
            var c = effective
            c.size = new
            session.fontOverride = c
          }
        ))
        Text("pt").foregroundStyle(.secondary)
        Stepper("", value: Binding(
          get: { effective.size },
          set: { new in
            var c = effective
            c.size = new
            session.fontOverride = c
          }
        ), in: 6...72, step: 1)
        .labelsHidden()
      }

      List(selection: Binding(
        get: { effective.name as String? },
        set: { new in
          guard let new else { return }
          var c = effective
          c.name = new
          session.fontOverride = c
        }
      )) {
        ForEach(FontCatalog.monospaced, id: \.self) { family in
          Text(family)
            .font(.custom(family, size: 13))
            .tag(family as String?)
        }
      }
      .frame(width: 320, height: 200)

      if session.fontOverride != nil {
        Button("전역 폰트로 되돌리기") { session.fontOverride = nil }
          .buttonStyle(.link)
          .font(.caption)
      }
    }
    .padding(14)
    .frame(width: 340)
  }
}
