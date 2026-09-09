import AppKit
import SwiftTerm

/// SwiftTerm 터미널 뷰에 붙일 우클릭 컨텍스트 메뉴.
/// 복사(⌘C) / 붙여넣기(⌘V) / 모두 선택(⌘A).
enum TerminalContextMenu {

  static func build(for view: LocalProcessTerminalView) -> NSMenu {
    let menu = NSMenu()
    // target 은 아래 TerminalMenuTarget. NSMenu 는 target 을 약참조하므로
    // view 에 associated object 로 붙여 lifetime 을 맞춰준다.
    let target = TerminalMenuTarget(view: view)
    objc_setAssociatedObject(view, &TerminalMenuTarget.key, target, .OBJC_ASSOCIATION_RETAIN)

    let copyItem = NSMenuItem(title: "복사", action: #selector(TerminalMenuTarget.copy(_:)), keyEquivalent: "c")
    copyItem.keyEquivalentModifierMask = [.command]
    copyItem.target = target

    let pasteItem = NSMenuItem(title: "붙여넣기", action: #selector(TerminalMenuTarget.paste(_:)), keyEquivalent: "v")
    pasteItem.keyEquivalentModifierMask = [.command]
    pasteItem.target = target

    let selectAllItem = NSMenuItem(title: "모두 선택", action: #selector(TerminalMenuTarget.selectAll(_:)), keyEquivalent: "a")
    selectAllItem.keyEquivalentModifierMask = [.command]
    selectAllItem.target = target

    menu.addItem(copyItem)
    menu.addItem(pasteItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(selectAllItem)
    return menu
  }
}

/// 메뉴 액션 라우팅용 헬퍼. NSMenu 가 view 에 direct action 을 못 넘겨서
/// 이 얇은 target 을 두고, 안에서 SwiftTerm API 를 호출한다.
final class TerminalMenuTarget: NSObject {
  static var key: UInt8 = 0
  weak var view: LocalProcessTerminalView?
  init(view: LocalProcessTerminalView) { self.view = view }

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
}
