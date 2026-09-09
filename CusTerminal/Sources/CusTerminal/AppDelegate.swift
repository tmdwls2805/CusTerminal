import AppKit
import SwiftUI

/// AppDelegate - Dock 아이콘 우클릭 메뉴에 모든 창(pane 세션) 나열.
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()

    // 모든 창 나열 (메인 + detached).
    // 각 창의 title (pane 이름) 을 클릭 → 그 창을 앞으로 가져옴.
    let windows = NSApp.windows.filter { $0.isVisible && !$0.title.isEmpty }
    for window in windows {
      let item = NSMenuItem(title: window.title, action: #selector(activateWindow(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = window
      // 앞에 아이콘 (터미널 창 표시).
      if let icon = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) {
        item.image = icon
      }
      menu.addItem(item)
    }
    return windows.isEmpty ? nil : menu
  }

  @objc private func activateWindow(_ sender: NSMenuItem) {
    guard let window = sender.representedObject as? NSWindow else { return }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}
