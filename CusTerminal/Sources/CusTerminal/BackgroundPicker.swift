import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 사이드바 하단 진입 버튼.
struct BackgroundPickerButton: View {
  @Environment(BackgroundStore.self) private var bgStore
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: bgStore.globalChoice.isEmpty ? "photo" : "photo.fill")
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 0) {
          Text("배경 이미지").font(.system(size: 12))
          Text(bgStore.globalChoice.isEmpty
               ? "없음"
               : "\(Int(bgStore.globalChoice.opacity * 100))% · \(bgStore.globalChoice.fit.label)")
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
      BackgroundPickerPopover()
    }
    .help("배경 이미지 설정")
  }
}

/// 배경 팝오버: 모드 토글 + 이미지 선택/드롭 + 옵션 슬라이더 + 미리보기.
struct BackgroundPickerPopover: View {
  @Environment(BackgroundStore.self) private var bgStore
  @Environment(\.currentLayoutStore) private var currentLayout

  var body: some View {
    @Bindable var store = bgStore
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("배경 이미지").font(.headline)
        Spacer()
        Picker("", selection: $store.mode) {
          Text("전역").tag(BackgroundMode.global)
          Text("세션별").tag(BackgroundMode.perPane)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }

      Text(store.mode == .global
           ? "선택한 배경이 모든 pane 에 적용됩니다."
           : "각 pane 헤더의 배경 버튼으로 개별 지정할 수 있습니다. 여기서 고른 것은 전역 기본이 됩니다.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      BackgroundEditor(
        choice: Binding(
          get: { store.globalChoice },
          set: { store.globalChoice = $0 }
        )
      )

      Divider()
      HStack {
        Button {
          store.resetToDefaults(sessions: currentLayout?.allSessions ?? [])
        } label: {
          Label("배경 없애기 · 기본값으로", systemImage: "arrow.uturn.backward")
            .font(.caption)
        }
        .buttonStyle(.borderless)
        Spacer()
      }
    }
    .padding(14)
    .frame(width: 360)
  }
}

/// pane 헤더용 세션-배경 버튼 (perPane 모드).
struct SessionBackgroundButton: View {
  @Environment(BackgroundStore.self) private var bgStore
  @ObservedObject var session: TerminalSession
  @State private var show: Bool = false

  var body: some View {
    Button { show.toggle() } label: {
      Image(systemName: (session.backgroundOverride?.isEmpty == false) ? "photo.fill" : "photo")
        .frame(width: 18, height: 16)
    }
    .buttonStyle(.borderless)
    .help("이 pane 의 배경 이미지 (세션별 모드)")
    .popover(isPresented: $show, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 10) {
        Text("이 pane 배경").font(.headline)
        BackgroundEditor(choice: Binding(
          get: { session.backgroundOverride ?? bgStore.globalChoice },
          set: { session.backgroundOverride = $0 }
        ))
        if session.backgroundOverride != nil {
          Button("전역 배경으로 되돌리기") {
            session.backgroundOverride = nil
          }
          .buttonStyle(.link)
          .font(.caption)
        }
      }
      .padding(14)
      .frame(width: 360)
    }
  }
}

/// 실제 편집 UI: 이미지 선택/드롭, 불투명도, 채우기 모드, 어둡게, 미리보기, 제거.
struct BackgroundEditor: View {
  @Binding var choice: BackgroundChoice
  @Environment(BackgroundStore.self) private var bgStore
  @State private var isDropTarget = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 미리보기 + 드롭 영역.
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(Color.black)
        if !choice.isEmpty, let img = bgStore.loadImage(choice.fileName) {
          Image(nsImage: img)
            .resizable()
            .aspectRatio(contentMode: choice.fit == .fit ? .fit : .fill)
            .opacity(choice.opacity)
          Color.black.opacity(choice.darkenAmount)
          Text(">_ 미리보기")
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
        } else {
          VStack(spacing: 4) {
            Image(systemName: "square.and.arrow.down")
              .font(.title2)
              .foregroundStyle(.secondary)
            Text("이미지를 여기 드롭하거나 아래 버튼으로 선택")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(height: 130)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isDropTarget ? Color.accentColor : Color(nsColor: .separatorColor),
                  lineWidth: isDropTarget ? 2 : 1)
      )
      .onDrop(of: [UTType.fileURL], isTargeted: $isDropTarget) { providers in
        handleDrop(providers: providers)
      }

      HStack(spacing: 8) {
        Button {
          pickImageFile()
        } label: {
          Label("이미지 선택…", systemImage: "photo.badge.plus")
        }
        if !choice.isEmpty {
          Button(role: .destructive) {
            choice.fileName = ""
          } label: {
            Label("제거", systemImage: "xmark")
          }
        }
      }
      .font(.caption)

      // 옵션.
      Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
        GridRow {
          Text("불투명도").frame(width: 60, alignment: .leading)
          Slider(value: $choice.opacity, in: 0.05...1.0)
          Text("\(Int(choice.opacity * 100))%")
            .monospacedDigit()
            .frame(width: 36, alignment: .trailing)
        }
        GridRow {
          Text("어둡게").frame(width: 60, alignment: .leading)
          Slider(value: $choice.darkenAmount, in: 0...0.8)
          Text("\(Int(choice.darkenAmount * 100))%")
            .monospacedDigit()
            .frame(width: 36, alignment: .trailing)
        }
        GridRow {
          Text("채우기").frame(width: 60, alignment: .leading)
          Picker("", selection: $choice.fit) {
            ForEach(BackgroundFit.allCases) { f in Text(f.label).tag(f) }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          Color.clear.frame(width: 36)
        }
      }
      .font(.caption)
    }
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: URL.self) { url, _ in
      guard let url else { return }
      DispatchQueue.main.async {
        if let name = bgStore.importImage(from: url) {
          choice.fileName = name
        }
      }
    }
    return true
  }

  private func pickImageFile() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.image]
    if panel.runModal() == .OK, let url = panel.url {
      if let name = bgStore.importImage(from: url) {
        choice.fileName = name
      }
    }
  }
}
