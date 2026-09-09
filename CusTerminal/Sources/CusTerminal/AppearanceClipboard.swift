import SwiftUI

/// pane 하나의 겉모습 (테마 + 폰트) 스냅샷.
struct AppearanceSnapshot: Equatable {
  var themeID: String
  var font: TerminalFontChoice
  var themeDisplayName: String  // 붙여넣기 메뉴 라벨용
}

/// 앱 전역 "테마 클립보드". 사용자가 pane 헤더에서 복사한 스타일을 잠시 보관.
@Observable
final class AppearanceClipboard {
  static let shared = AppearanceClipboard()
  var snapshot: AppearanceSnapshot?

  private init() {}

  func copy(from session: TerminalSession,
            themeStore: ThemeStore,
            fontStore: FontStore) {
    let theme = themeStore.themeFor(session: session)
    let font = fontStore.fontFor(session: session)
    snapshot = AppearanceSnapshot(themeID: theme.id, font: font, themeDisplayName: theme.name)
  }

  func paste(to session: TerminalSession,
             themeStore: ThemeStore,
             fontStore: FontStore) {
    guard let snap = snapshot else { return }
    // 붙여넣기는 특정 pane 만 바꾸는 의미 → 세션별 모드로 자동 전환.
    themeStore.mode = .perPane
    fontStore.mode = .perPane
    session.themeIDOverride = snap.themeID
    session.fontOverride = snap.font
  }

  func clear() { snapshot = nil }
}
