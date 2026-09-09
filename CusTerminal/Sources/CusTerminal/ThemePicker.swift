import SwiftUI

/// 사이드바 하단에 얹는 테마 진입점 + 팝오버 팔레트.
struct ThemePickerButton: View {
  @Environment(ThemeStore.self) private var themeStore
  @Environment(CustomThemeStore.self) private var customStore
  @State private var showPalette: Bool = false
  @State private var showEditor: Bool = false
  @State private var editing: TerminalTheme? = nil

  var body: some View {
    Button {
      showPalette.toggle()
    } label: {
      HStack(spacing: 8) {
        ThemeSwatch(theme: themeStore.globalTheme, size: 18)
        Text(themeStore.globalTheme.name)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer()
        Image(systemName: "paintpalette")
          .foregroundStyle(.secondary)
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
    .popover(isPresented: $showPalette, arrowEdge: .top) {
      ThemePalettePopover(
        onRequestEditor: { theme in
          editing = theme
          showPalette = false        // 편집 시트 열기 전에 팔레트 먼저 닫음
          // 살짝 딜레이 두고 시트 표시 (팝오버 dismiss 애니메이션과 겹치면 시트가 안 뜨는 경우 있음)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showEditor = true
          }
        }
      )
    }
    .sheet(isPresented: $showEditor) {
      CustomThemeEditor(
        existing: editing,
        onSave: { theme in
          customStore.upsert(theme)
          showEditor = false
          // 저장 후 팔레트가 다시 열리지 않도록 명시.
          showPalette = false
        },
        onCancel: {
          showEditor = false
          showPalette = false
        }
      )
    }
    .help("테마 변경")
  }
}

/// 팝오버 안 그리드: 모드 토글 + 프리셋 20개 + 커스텀 테마들 + "새로 만들기".
/// 편집 시트는 부모(ThemePickerButton) 가 관리 → 시트/팔레트 동시 닫기 위해.
struct ThemePalettePopover: View {
  @Environment(ThemeStore.self) private var themeStore
  @Environment(CustomThemeStore.self) private var customStore
  /// editing = nil 이면 새로 만들기, 있으면 편집.
  let onRequestEditor: (TerminalTheme?) -> Void

  private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

  var body: some View {
    @Bindable var store = themeStore
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("테마")
          .font(.headline)
        Spacer()
        Picker("", selection: $store.mode) {
          Text("전역").tag(ThemeMode.global)
          Text("세션별").tag(ThemeMode.perPane)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }

      Text(store.mode == .global
           ? "선택한 테마가 모든 pane 에 즉시 적용됩니다."
           : "선택한 테마가 전역 기본으로 저장되고, 각 pane 은 헤더의 팔레트 버튼으로 개별 지정할 수 있습니다.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ScrollView {
        LazyVGrid(columns: columns, spacing: 8) {
          ForEach(ThemeCatalog.all) { theme in
            ThemeCard(
              theme: theme,
              selected: theme.id == store.globalThemeID,
              action: { store.apply(themeID: theme.id, to: nil) }
            )
          }
          ForEach(customStore.themes) { theme in
            ThemeCard(
              theme: theme,
              selected: theme.id == store.globalThemeID,
              action: { store.apply(themeID: theme.id, to: nil) },
              onEdit: { onRequestEditor(theme) },
              onDelete: {
                customStore.remove(id: theme.id)
                if store.globalThemeID == theme.id {
                  store.globalThemeID = "classic-dark"
                }
              }
            )
          }
          NewThemeCard {
            onRequestEditor(nil)
          }
        }
      }
      .frame(width: 400, height: 320)
    }
    .padding(14)
  }
}

/// pane 헤더 옆에 붙일 세션별 테마 픽커 (per-pane 모드일 때만 노출).
struct SessionThemeButton: View {
  @Environment(ThemeStore.self) private var themeStore
  @ObservedObject var session: TerminalSession
  @State private var show: Bool = false

  var body: some View {
    Button {
      show.toggle()
    } label: {
      Image(systemName: "paintpalette")
        .frame(width: 18, height: 16)
    }
    .buttonStyle(.borderless)
    .help("이 pane 의 테마 변경 (세션별 모드)")
    .popover(isPresented: $show, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 10) {
        Text("이 pane 테마")
          .font(.headline)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
          ForEach(ThemeCatalog.all) { theme in
            ThemeCard(
              theme: theme,
              selected: theme.id == (session.themeIDOverride ?? themeStore.globalThemeID),
              action: {
                themeStore.apply(themeID: theme.id, to: session)
                show = false
              }
            )
          }
        }
        .frame(width: 400)
        if session.themeIDOverride != nil {
          Button("전역 테마로 되돌리기") {
            session.themeIDOverride = nil
            show = false
          }
          .buttonStyle(.link)
          .font(.caption)
        }
      }
      .padding(14)
    }
  }
}

/// 개별 테마 카드: 색상 프리뷰 + 이름 + 선택 상태.
/// 커스텀 테마인 경우 onEdit / onDelete 를 넘기면 우클릭 컨텍스트 메뉴 활성화.
private struct ThemeCard: View {
  let theme: TerminalTheme
  let selected: Bool
  let action: () -> Void
  var onEdit: (() -> Void)? = nil
  var onDelete: (() -> Void)? = nil

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        ZStack {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: theme.background))
          Text(">_")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(Color(nsColor: theme.foreground))
        }
        .frame(height: 40)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: selected ? 2 : 1)
        )
        Text(theme.name)
          .font(.system(size: 10))
          .lineLimit(1)
          .foregroundStyle(.primary)
      }
      .padding(4)
    }
    .buttonStyle(.plain)
    .contextMenu {
      if let onEdit { Button("편집", action: onEdit) }
      if let onDelete { Button("삭제", role: .destructive, action: onDelete) }
    }
  }
}

/// 커스텀 테마 새로 만들기 카드.
private struct NewThemeCard: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        ZStack {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .controlBackgroundColor))
          VStack(spacing: 2) {
            Image(systemName: "plus.circle").font(.system(size: 18))
            Text("새로 만들기").font(.system(size: 9))
          }
          .foregroundStyle(.secondary)
        }
        .frame(height: 40)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundColor(Color(nsColor: .separatorColor))
        )
        Text("커스텀")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
      .padding(4)
    }
    .buttonStyle(.plain)
  }
}

/// 커스텀 테마 편집 시트: 이름 + 4색 피커 + 실시간 프리뷰.
struct CustomThemeEditor: View {
  let existing: TerminalTheme?
  let onSave: (TerminalTheme) -> Void
  let onCancel: () -> Void

  @State private var name: String = ""
  @State private var background: Color = .black
  @State private var foreground: Color = .white
  @State private var cursor: Color = .white
  @State private var selection: Color = Color(nsColor: NSColor(hex: "#3D3D3D") ?? .darkGray)

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(existing == nil ? "커스텀 테마 만들기" : "커스텀 테마 편집")
        .font(.headline)

      HStack {
        Text("이름").frame(width: 60, alignment: .leading)
        TextField("예: 내 테마", text: $name)
          .textFieldStyle(.roundedBorder)
      }

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
        GridRow {
          Text("배경").frame(width: 60, alignment: .leading)
          ColorWell(color: $background).frame(width: 44, height: 24)
          Spacer()
        }
        GridRow {
          Text("글자").frame(width: 60, alignment: .leading)
          ColorWell(color: $foreground).frame(width: 44, height: 24)
          Spacer()
        }
        GridRow {
          Text("커서").frame(width: 60, alignment: .leading)
          ColorWell(color: $cursor).frame(width: 44, height: 24)
          Spacer()
        }
        GridRow {
          Text("선택").frame(width: 60, alignment: .leading)
          ColorWell(color: $selection).frame(width: 44, height: 24)
          Spacer()
        }
      }

      // 큰 프리뷰
      VStack(alignment: .leading, spacing: 0) {
        Text("미리보기")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.bottom, 4)
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 8)
            .fill(background)
          VStack(alignment: .leading, spacing: 2) {
            Text("silverslab@Mac ~ %")
            HStack(spacing: 0) {
              Text(" ls").padding(.leading, 2)
              Rectangle().fill(cursor).frame(width: 8, height: 14)
            }
            Text("Desktop  Documents  Downloads")
              .padding(.top, 2)
            HStack(spacing: 0) {
              Text("selected").padding(2).background(selection)
              Text(" 텍스트")
            }
            .padding(.top, 6)
          }
          .foregroundColor(foreground)
          .font(.system(size: 12, design: .monospaced))
          .padding(12)
        }
        .frame(height: 130)
      }

      HStack {
        Spacer()
        Button("취소", action: onCancel)
        Button("저장") { save() }
          .keyboardShortcut(.defaultAction)
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(20)
    .frame(width: 420)
    .background(SheetWindowFinder { window in
      // 시트가 뜨면 NSColorPanel 위치를 시트 오른쪽에 붙여 편집에 가깝게.
      positionColorPanel(near: window)
    })
    .onAppear {
      if let existing {
        name = existing.name
        background = Color(nsColor: existing.background)
        foreground = Color(nsColor: existing.foreground)
        cursor = Color(nsColor: existing.cursor)
        selection = Color(nsColor: existing.selection)
      }
    }
    .onDisappear {
      // 시트 닫을 때 열려있던 Colors 창도 함께 닫음.
      let panel = NSColorPanel.shared
      if panel.isVisible { panel.orderOut(nil) }
    }
  }

  /// NSColorPanel 을 시트 옆에 배치. 시트 오른쪽 여유 공간이 부족하면 왼쪽으로.
  private func positionColorPanel(near sheetWindow: NSWindow?) {
    guard let sheetWindow else { return }
    let panel = NSColorPanel.shared
    // 사용자가 처음 well 을 클릭하기 전엔 크기가 0 일 수 있음 → 기본 크기 강제.
    if panel.frame.size.width < 100 {
      panel.setContentSize(NSSize(width: 220, height: 300))
    }
    let sheetFrame = sheetWindow.frame
    let panelSize = panel.frame.size
    let gap: CGFloat = 12

    // 오른쪽에 붙이기 우선. 화면 밖으로 나가면 왼쪽으로.
    var x = sheetFrame.maxX + gap
    let screenMaxX = (sheetWindow.screen ?? NSScreen.main)?.visibleFrame.maxX ?? x + panelSize.width
    if x + panelSize.width > screenMaxX {
      x = sheetFrame.minX - panelSize.width - gap
    }
    let y = sheetFrame.midY - panelSize.height / 2
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }

  private func save() {
    let id = existing?.id ?? "custom-\(UUID().uuidString.prefix(8))"
    let theme = TerminalTheme(
      id: id,
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      backgroundHex: NSColor(background).srgbHex,
      foregroundHex: NSColor(foreground).srgbHex,
      cursorHex: NSColor(cursor).srgbHex,
      selectionHex: NSColor(selection).srgbHex
    )
    onSave(theme)
  }
}

/// SwiftUI 뷰에서 현재 속한 NSWindow 를 얻기 위한 브릿지.
private struct SheetWindowFinder: NSViewRepresentable {
  let onFound: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let v = NSView()
    DispatchQueue.main.async { onFound(v.window) }
    return v
  }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 원형 스와치 (사이드바 진입 버튼용).
struct ThemeSwatch: View {
  let theme: TerminalTheme
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Color(nsColor: theme.background))
      Text(">")
        .font(.system(size: size * 0.55, weight: .bold, design: .monospaced))
        .foregroundColor(Color(nsColor: theme.foreground))
    }
    .frame(width: size, height: size)
    .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
  }
}
