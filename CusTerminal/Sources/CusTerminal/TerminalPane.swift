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
  let history = HistoryStore()
  @Published var name: String = ""
  @Published var themeIDOverride: String?
  @Published var fontOverride: TerminalFontChoice?
  @Published var backgroundOverride: BackgroundChoice?

  static func == (lhs: TerminalSession, rhs: TerminalSession) -> Bool { lhs.id == rhs.id }
}

/// LocalProcessTerminalView 참조를 유지해 send 를 호출할 수 있게 한다.
/// 뷰(NSView) 자체를 캐시해서 SwiftUI 가 뷰를 재생성해도 같은 PTY 를 보여준다.
final class TerminalHolder: ObservableObject {
  var view: LocalProcessTerminalView?
  /// 훅 초기 등록이 한 번만 실행되도록 플래그.
  var didApplyInitialHooks: Bool = false
  /// 마지막 적용된 값 캐시 → 동일 값이면 redraw 유발하는 세팅 스킵.
  private var lastThemeID: String?
  private var lastTransparent: Bool = false
  private var lastFontName: String?
  private var lastFontSize: CGFloat = 0
  /// 훅 재적용 판단용. 세션 lifetime 내내 유지 (Coordinator 는 창 이동 시 리셋되므로).
  var lastSepFingerprint: String = ""

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

  /// 셸을 거치지 않고 화면 버퍼에 텍스트 직접 쓰기 (구분선용).
  /// - 셸이 알지 못하므로 명령 이력에도 안 남고, prompt 갱신도 안 시킴.
  func feedToScreen(_ text: String) {
    guard let view else { return }
    Log.write("feedToScreen len=\(text.count) preview=\(text.prefix(30).debugDescription)")
    view.getTerminal().feed(text: text)
  }

  /// 훅 스크립트를 파일에 저장하고 셸에 source 실행.
  /// - alsoClear=true (초기 등록): source 뒤에 clear 붙이고 앱이 스크롤백까지 지움
  /// - alsoClear=false (재적용): 작업 중일 수 있으니 화면을 절대 건드리지 않음
  private func sourceScript(_ script: String, alsoClear: Bool) {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("CusTerminal-hooks", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("hook-\(UUID().uuidString).zsh")
    try? script.write(to: file, atomically: true, encoding: .utf8)
    let tail = alsoClear ? "; clear" : ""
    let line = " source '\(file.path)' 2>/dev/null; rm -f '\(file.path)' 2>/dev/null\(tail)\n"
    send(text: line)
    // ✗ 이전에는 여기서 앱이 \e[3J\e[H\e[2J 를 feed 로 강제 주입했는데,
    //   그 순간 셸이 이미 그린 새 프롬프트가 함께 지워져서 화면이 빈 채로 남았음.
    //   → clear 셸 명령이 이미 화면 정리를 하므로 앱의 강제 clear 는 제거.
  }

  /// 구분선 훅 적용/해제 (설정 변경 시 재적용).
  func applySeparator(_ sep: SeparatorStore, initial: Bool = false) {
    let script = sep.enabled ? sep.zshHookScript() : sep.zshHookDisableScript()
    sourceScript(script, alsoClear: initial)
  }

  /// 히스토리 preexec/precmd 훅 등록 (단독 호출용, 지금은 미사용).
  func applyHistoryHook(_ history: HistoryStore) {
    sourceScript(history.zshAppendHookScript(), alsoClear: false)
  }

  /// pane 첫 시작 시 구분선 + 히스토리 훅을 한 번에 등록.
  /// 한 번의 source + clear 로 화면 흔적 최소화.
  /// - 앞부분에 add-zsh-hook -d 로 기존 훅을 먼저 제거해서 source 자체가 훅에 안 잡히게.
  func applyInitialHooks(separator sep: SeparatorStore, history: HistoryStore) {
    let disable = """
    autoload -Uz add-zsh-hook 2>/dev/null; \
    add-zsh-hook -d preexec __cust_pre 2>/dev/null; \
    add-zsh-hook -d precmd __cust_post 2>/dev/null; \
    add-zsh-hook -d preexec __cust_hist_pre 2>/dev/null; \
    add-zsh-hook -d precmd __cust_hist_post 2>/dev/null
    """
    let sepScript = sep.enabled ? sep.zshHookScript() : sep.zshHookDisableScript()
    let historyScript = history.zshAppendHookScript()
    let combined = disable
      + "; " + sepScript.trimmingCharacters(in: .whitespacesAndNewlines)
      + "; " + historyScript.trimmingCharacters(in: .whitespacesAndNewlines)
    sourceScript(combined, alsoClear: true)
  }

  /// 테마 색상을 즉시 적용. 같은 값이면 skip → SwiftUI updateNSView 반복 호출 시 redraw 방지.
  func applyTheme(_ theme: TerminalTheme, transparent: Bool = false) {
    guard let view else { return }
    if lastThemeID == theme.id && lastTransparent == transparent { return }
    Log.write("applyTheme id=\(theme.id) transparent=\(transparent) [CHANGED]")
    lastThemeID = theme.id
    lastTransparent = transparent
    view.nativeBackgroundColor = transparent ? .clear : theme.background
    view.nativeForegroundColor = theme.foreground
    view.caretColor = theme.cursor
    view.selectedTextBackgroundColor = theme.selection
    view.wantsLayer = true
    view.layer?.backgroundColor = (transparent ? NSColor.clear : theme.background).cgColor
    view.needsDisplay = true
  }

  /// 폰트 적용. 같은 값이면 skip.
  func applyFont(_ choice: TerminalFontChoice) {
    guard let view else { return }
    if lastFontName == choice.name && lastFontSize == choice.size { return }
    lastFontName = choice.name
    lastFontSize = choice.size
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
  @Environment(SeparatorStore.self) private var sepStore
  @Environment(DropRunStore.self) private var dropRunStore

  private var currentTheme: TerminalTheme { themeStore.themeFor(session: session) }
  private var currentFont: TerminalFontChoice { fontStore.fontFor(session: session) }
  private var currentBackground: BackgroundChoice { backgroundStore.backgroundFor(session: session) }

  /// SeparatorStore 의 관찰할 필드들을 한 문자열로 → 변경 감지용.
  private var sepFingerprint: String {
    "\(sepStore.enabled)|\(sepStore.startChar)|\(sepStore.endChar)|\(sepStore.startLabel)|\(sepStore.endLabel)|\(sepStore.padCount)"
  }

  var body: some View {
    ZStack {
      // 배경 색상 (항상 같은 위치, 값만 바뀜)
      Color(nsColor: currentTheme.background)

      // 배경 이미지 오버레이 (항상 있는 자리, 이미지 없으면 투명)
      BackgroundLayer(choice: currentBackground, store: backgroundStore)

      // 터미널 뷰 (identity 절대 안 바뀜)
      TerminalHost(holder: session.holder,
                   session: session,
                   themeStore: themeStore,
                   fontStore: fontStore,
                   sepStore: sepStore,
                   theme: currentTheme,
                   font: currentFont,
                   backgroundVisible: !currentBackground.isEmpty,
                   sepFingerprint: sepFingerprint)
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
      // 텍스트(카드) 드롭 → 명령 텍스트 send.
      // 카드에서 온 payload 는 "CUSTERMINAL_CARD:<uuid>:<text>" 형식이므로 stripping.
      guard let provider = providers.first else { return false }
      _ = provider.loadObject(ofClass: NSString.self) { item, _ in
        guard let text = item as? String else { return }
        var command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "CUSTERMINAL_CARD:"
        if command.hasPrefix(prefix) {
          let rest = String(command.dropFirst(prefix.count))
          // <uuid>:<text> → 두 번째 콜론 이후가 실제 명령.
          let parts = rest.split(separator: ":", maxSplits: 1)
          if parts.count == 2 { command = String(parts[1]) }
        }
        guard !command.isEmpty else { return }
        DispatchQueue.main.async {
          let payload = dropRunStore.autoRun ? command + "\n" : command
          session.holder.send(text: payload)
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

/// 여러 라인을 각각 별개 명령으로 셸에 send. 각 라인 사이에 짧은 delay.
private func sendLinesSequentially(_ lines: [String], to session: TerminalSession, index: Int = 0) {
  guard index < lines.count else { return }
  let line = lines[index]
  session.holder.send(text: line + "\n")
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
    sendLinesSequentially(lines, to: session, index: index + 1)
  }
}


/// 배경 이미지 오버레이. 이미지 없으면 투명, 있으면 opacity + darken.
/// 항상 같은 자리에 존재해서 SwiftUI 뷰 identity 유지 → 터미널 리렌더 유발 X.
private struct BackgroundLayer: View {
  let choice: BackgroundChoice
  let store: BackgroundStore

  var body: some View {
    if choice.isEmpty {
      Color.clear
    } else if let image = store.loadImage(choice.fileName) {
      ZStack {
        BackgroundImageView(image: image, fit: choice.fit)
          .opacity(choice.opacity)
        Color.black.opacity(choice.darkenAmount)
      }
    } else {
      Color.clear
    }
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
  let sepStore: SeparatorStore
  let theme: TerminalTheme
  let font: TerminalFontChoice
  let backgroundVisible: Bool
  /// 값이 바뀌면 SwiftUI 가 updateNSView 를 호출해 hook 재적용.
  let sepFingerprint: String

  func makeNSView(context: Context) -> LocalProcessTerminalView {
    let v = holder.makeIfNeeded()
    TerminalContextMenu.attach(to: v, session: session, themeStore: themeStore, fontStore: fontStore)
    holder.applyTheme(theme, transparent: backgroundVisible)
    holder.applyFont(font)
    Log.write("makeNSView session=\(session.id.uuidString.prefix(4)) didApply=\(holder.didApplyInitialHooks)")
    // 셸 초기화(cd ~ && clear) 뒤 hook 적용 + 화면 클리어.
    // 세션 lifetime 에 딱 한 번만 실행. (makeNSView 가 여러 번 호출되어도 반복 안 됨)
    if !holder.didApplyInitialHooks {
      holder.didApplyInitialHooks = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        holder.applyInitialHooks(separator: sepStore, history: session.history)
        holder.lastSepFingerprint = sepFingerprint
      }
    }
    return v
  }

  func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
    holder.applyTheme(theme, transparent: backgroundVisible)
    holder.applyFont(font)
    // 초기 훅 등록 전엔 재적용 시도 자체를 skip (초기 등록이 fingerprint 도 세팅).
    guard holder.didApplyInitialHooks else { return }
    // 설정 실제 변경 시에만 hook 재등록. holder 에 fingerprint 저장 →
    // 창 이동(새 SwiftUI Coordinator 생성) 후에도 중복 재적용 방지.
    if holder.lastSepFingerprint != sepFingerprint {
      holder.lastSepFingerprint = sepFingerprint
      holder.applySeparator(sepStore)
    }
  }
}
