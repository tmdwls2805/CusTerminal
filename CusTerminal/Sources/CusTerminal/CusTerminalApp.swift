import SwiftUI

@main
struct CusTerminalApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup("CusTerminal") {
      ContentView()
        .frame(minWidth: 720, minHeight: 480)
    }
  }
}
