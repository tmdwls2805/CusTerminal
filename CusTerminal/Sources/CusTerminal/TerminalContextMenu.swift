import AppKit
import SwiftTerm

/// SwiftTerm 터미널 뷰에 붙일 우클릭 컨텍스트 메뉴.
/// 복사(⌘C) / 붙여넣기(⌘V) / 모두 선택(⌘A) + 테마 복사·붙여넣기·되돌리기.
enum TerminalContextMenu {

  /// 세션과 스토어를 참조하는 target 을 뷰에 associated object 로 붙이고,
  /// 매뉴는 delegate 로 매번 재생성 → 클립보드 상태 반영.
  static func attach(to view: LocalProcessTerminalView,
                     session: TerminalSession,
                     themeStore: ThemeStore,
                     fontStore: FontStore) {
    let target = TerminalMenuTarget(view: view,
                                    session: session,
                                    themeStore: themeStore,
                                    fontStore: fontStore)
    objc_setAssociatedObject(view, &TerminalMenuTarget.key, target, .OBJC_ASSOCIATION_RETAIN)

    let menu = NSMenu()
    menu.delegate = target
    view.menu = menu
  }
}

/// 메뉴 액션 라우팅 + 동적 재생성.
final class TerminalMenuTarget: NSObject, NSMenuDelegate {
  static var key: UInt8 = 0
  weak var view: LocalProcessTerminalView?
  weak var session: TerminalSession?
  weak var themeStore: ThemeStore?
  weak var fontStore: FontStore?

  init(view: LocalProcessTerminalView,
       session: TerminalSession,
       themeStore: ThemeStore,
       fontStore: FontStore) {
    self.view = view
    self.session = session
    self.themeStore = themeStore
    self.fontStore = fontStore
  }

  // MARK: - NSMenuDelegate

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    // 기본 편집 항목.
    menu.addItem(item("복사", action: #selector(copy(_:)), key: "c"))
    menu.addItem(item("붙여넣기", action: #selector(paste(_:)), key: "v"))
    menu.addItem(.separator())
    menu.addItem(item("모두 선택", action: #selector(selectAll(_:)), key: "a"))

    // 테마 그룹.
    menu.addItem(.separator())
    menu.addItem(item("테마 복사", action: #selector(copyTheme(_:))))

    let clip = AppearanceClipboard.shared
    if let snap = clip.snapshot {
      let label = "테마 붙여넣기 (\(snap.themeDisplayName) · \(snap.font.name) \(Int(snap.font.size))pt)"
      menu.addItem(item(label, action: #selector(pasteTheme(_:))))
      menu.addItem(item("복사한 테마 지우기", action: #selector(clearTheme(_:))))
    }

    // 되돌리기: 항상 활성. 오버라이드 없으면 전역도 기본값으로 리셋.
    menu.addItem(item("이 pane 기본값으로 되돌리기", action: #selector(resetOverrides(_:))))
  }

  private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
    let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
    if !key.isEmpty { it.keyEquivalentModifierMask = [.command] }
    it.target = self
    return it
  }

  // MARK: - 기본 편집

  @objc func copy(_ sender: Any?) {
    guard let view else { return }
    let text = view.selection.getSelectedText()
    guard !text.isEmpty else { return }
    let pb = NSPasteboard.general
    pb.declareTypes([.string], owner: nil)
    pb.setString(text, forType: .string)
  }

  @objc func paste(_ sender: Any?) {
    guard let view else { return }
    guard let text = NSPasteboard.general.string(forType: .string) else { return }
    view.send(data: Array(text.utf8)[...])
  }

  @objc func selectAll(_ sender: Any?) {
    view?.selectAll(sender)
  }

  // MARK: - 테마 조작

  @objc func copyTheme(_ sender: Any?) {
    guard let session, let themeStore, let fontStore else { return }
    AppearanceClipboard.shared.copy(from: session, themeStore: themeStore, fontStore: fontStore)
  }

  @objc func pasteTheme(_ sender: Any?) {
    guard let session, let themeStore, let fontStore else { return }
    AppearanceClipboard.shared.paste(to: session, themeStore: themeStore, fontStore: fontStore)
  }

  @objc func clearTheme(_ sender: Any?) {
    AppearanceClipboard.shared.clear()
  }

  /// "이 pane 기본값으로 되돌리기" 규칙:
  /// 1. 개별 오버라이드가 있으면 그것만 지움 (전역은 유지)
  /// 2. 없다면 (이미 전역을 따르고 있다면) 전역 자체를 초기값(Classic Dark / Menlo 12pt) 으로 리셋
  ///    → 사용자가 눌렀을 때 "아무 반응 없음" 을 방지.
  @objc func resetOverrides(_ sender: Any?) {
    guard let session else { return }
    let hasOverride = (session.themeIDOverride != nil) || (session.fontOverride != nil)
    if hasOverride {
      session.themeIDOverride = nil
      session.fontOverride = nil
    } else {
      themeStore?.globalThemeID = "classic-dark"
      themeStore?.mode = .global
      fontStore?.globalFont = .default
      fontStore?.mode = .global
    }
  }
}
