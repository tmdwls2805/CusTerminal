import SwiftUI

@main
struct CusTerminalApp: App {
  var body: some Scene {
    WindowGroup("CusTerminal") {
      ContentView()
        .frame(minWidth: 720, minHeight: 480)
    }
    // 새 창(detached window)과 동일한 룩 앤 필: 상단 "CusTerminal" 타이틀바 표시.
  }
}
