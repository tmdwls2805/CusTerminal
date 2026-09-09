import SwiftUI
import AppKit
import SwiftTerm
import UniformTypeIdentifiers

/// 컬럼 = 세로로 쌓인 pane 들.
final class TerminalColumn: Identifiable, ObservableObject {
  let id = UUID()
  @Published var sessions: [TerminalSession]
  init(sessions: [TerminalSession]) { self.sessions = sessions }
}

/// 세션은 참조 타입: pane 이 옮겨다녀도 같은 PTY 를 재사용하도록 holder 를 여기서 소유.
/// 이름/테마도 세션에 붙어서 pane 이동/새 창 분리해도 따라감.
final class TerminalSession: Identifiable, ObservableObject, Equatable {
  let id = UUID()
  let holder = TerminalHolder()
  @Published var name: String = ""
  /// per-pane 모드일 때만 사용. nil 이면 전역 테마 fallback.
  @Published var themeIDOverride: String?
  /// per-pane 모드일 때만 사용. nil 이면 전역 폰트 fallback.
  @Published var fontOverride: TerminalFontChoice?
  /// per-pane 모드일 때만 사용. nil 이면 전역 배경 fallback.
  @Published var backgroundOverride: BackgroundChoice?

  static func == (lhs: TerminalSession, rhs: TerminalSession) -> Bool { lhs.id == rhs.id }
}

/// LocalProcessTerminalView 참조를 유지해 send 를 호출할 수 있게 한다.
/// 뷰(NSView) 자체를 캐시해서 SwiftUI 가 뷰를 재생성해도 같은 PTY 를 보여준다.
final class TerminalHolder: ObservableObject {
  var view: LocalProcessTerminalView?

  func makeIfNeeded() -> LocalProcessTerminalView {
    if let view { return view }
    let v = LocalProcessTerminalView(frame: .zero)
    // 배경 검정 / 글자 순수 흰색으로 강제. (기본은 흐릿한 회색톤)
    v.nativeBackgroundColor = .black
    v.nativeForegroundColor = .white
    // 컨텍스트 메뉴는 세션·스토어를 아는 TerminalHost 쪽에서 attach.
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    var env = ProcessInfo.processInfo.environment
    env["HOME"] = home
    env["PWD"] = home
    let envArray = env.map { "\($0.key)=\($0.value)" }
    v.startProcess(executable: shell, args: ["-l"], environment: envArray, execName: nil)
    self.view = v
    // login shell 이 .zprofile/.zshrc 를 로드하며 cd 를 걸 수 있으니,
    // 셸 초기화가 끝난 뒤 홈으로 강제 이동 + 화면을 깔끔히 지운다.
    // `clear` 로 앞선 `cd` 입력 흔적까지 비워서 홈에서 방금 열린 것처럼 보이게.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self, let v = self.view else { return }
      let bootstrap = " cd ~ && clear\n"  // 히스토리 오염 방지 위해 앞에 공백 (HIST_IGNORE_SPACE 사용자 배려)
      v.send(data: Array(bootstrap.utf8)[...])
    }
    return v
  }

  func send(text: String) {
    guard let view else { return }
    view.send(data: Array(text.utf8)[...])
  }

  /// 테마 색상을 즉시 적용.
  /// - transparent: 배경 이미지가 있을 때 SwiftTerm 자체 배경을 완전 투명으로 만들어 뒤 이미지를 보임.
  func applyTheme(_ theme: TerminalTheme, transparent: Bool = false) {
    guard let view else { return }
    view.nativeBackgroundColor = transparent ? .clear : theme.background
    view.nativeForegroundColor = theme.foreground
    view.caretColor = theme.cursor
    view.selectedTextBackgroundColor = theme.selection
    // 투명한 배경을 실제로 그리려면 layer/wantsLayer 도 설정 필요.
    view.wantsLayer = true
    view.layer?.backgroundColor = (transparent ? NSColor.clear : theme.background).cgColor
    view.needsDisplay = true
  }

  /// 폰트를 즉시 적용. 매칭되는 폰트가 없으면 시스템 모노스페이스 fallback.
  func applyFont(_ choice: TerminalFontChoice) {
    guard let view else { return }
    let font = NSFont(name: choice.name, size: choice.size)
      ?? NSFont.monospacedSystemFont(ofSize: choice.size, weight: .regular)
    view.font = font
  }
}

/// SwiftTerm 의 LocalProcessTerminalView 를 SwiftUI 로 감싼 뷰.
/// 텍스트 드롭 → 그 문자열 + \n 을 세션에 write.
struct TerminalPane: View {
  @ObservedObject var session: TerminalSession
  @Environment(ThemeStore.self) private var themeStore
  @Environment(FontStore.self) private var fontStore
  @Environment(BackgroundStore.self) private var backgroundStore

  private var currentTheme: TerminalTheme { themeStore.themeFor(session: session) }
  private var currentFont: TerminalFontChoice { fontStore.fontFor(session: session) }
  private var currentBackground: BackgroundChoice { backgroundStore.backgroundFor(session: session) }

  var body: some View {
    ZStack {
      // 최하단: 이미지 (있으면) → 그 위에 반투명 검정 오버레이 → 그 위에 터미널.
      if !currentBackground.isEmpty,
         let image = backgroundStore.loadImage(currentBackground.fileName) {
        BackgroundImageView(image: image, fit: currentBackground.fit)
          .opacity(currentBackground.opacity)
        Color.black.opacity(currentBackground.darkenAmount)
      } else {
        Color(nsColor: currentTheme.background)
      }

      TerminalHost(holder: session.holder,
                   session: session,
                   themeStore: themeStore,
                   fontStore: fontStore,
                   theme: currentTheme,
                   font: currentFont,
                   backgroundVisible: !currentBackground.isEmpty)
    }
    .onDrop(of: [UTType.plainText, UTType.utf8PlainText, UTType.fileURL], isTargeted: nil) { providers in
      // 이미지 파일 드롭 → 세션 배경으로 설정.
      for p in providers where p.canLoadObject(ofClass: URL.self) {
        _ = p.loadObject(ofClass: URL.self) { url, _ in
          guard let url, isImage(url) else { return }
          DispatchQueue.main.async {
            if let name = backgroundStore.importImage(from: url) {
              var choice = currentBackground.isEmpty ? BackgroundChoice.none : currentBackground
              choice.fileName = name
              backgroundStore.mode = .perPane
              session.backgroundOverride = choice
            }
          }
        }
        return true
      }
      // 텍스트(카드) 드롭 → 명령 실행 (기존 동작).
      guard let provider = providers.first else { return false }
      _ = provider.loadObject(ofClass: NSString.self) { item, _ in
        guard let text = item as? String else { return }
        DispatchQueue.main.async {
          session.holder.send(text: text + "\n")
        }
      }
      return true
    }
  }

  private func isImage(_ url: URL) -> Bool {
    let exts = ["jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff", "webp"]
    return exts.contains(url.pathExtension.lowercased())
  }
}

/// 배경 이미지를 fit 모드에 따라 그린다.
private struct BackgroundImageView: NSViewRepresentable {
  let image: NSImage
  let fit: BackgroundFit

  func makeNSView(context: Context) -> NSImageView {
    let v = NSImageView()
    v.image = image
    v.imageAlignment = .alignCenter
    v.imageScaling = scaling(for: fit)
    return v
  }
  func updateNSView(_ nsView: NSImageView, context: Context) {
    nsView.image = image
    nsView.imageScaling = scaling(for: fit)
  }
  private func scaling(for fit: BackgroundFit) -> NSImageScaling {
    switch fit {
    case .fill: return .scaleProportionallyUpOrDown  // 정확한 fill 아님 (아래 note)
    case .fit: return .scaleProportionallyDown
    case .stretch: return .scaleAxesIndependently
    }
  }
}

/// NSViewRepresentable: holder 가 캐시한 NSView 를 그대로 사용해 PTY 를 유지한다.
/// theme 변경 시 색상 즉시 반영.
struct TerminalHost: NSViewRepresentable {
  let holder: TerminalHolder
  let session: TerminalSession
  let themeStore: ThemeStore
  let fontStore: FontStore
  let theme: TerminalTheme
  let font: TerminalFontChoice
  /// 배경 이미지가 뒤에 있으면 SwiftTerm 배경을 투명하게.
  let backgroundVisible: Bool

  func makeNSView(context: Context) -> LocalProcessTerminalView {
    let v = holder.makeIfNeeded()
    TerminalContextMenu.attach(to: v, session: session, themeStore: themeStore, fontStore: fontStore)
    holder.applyTheme(theme, transparent: backgroundVisible)
    holder.applyFont(font)
    return v
  }

  func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
    holder.applyTheme(theme, transparent: backgroundVisible)
    holder.applyFont(font)
  }
}
