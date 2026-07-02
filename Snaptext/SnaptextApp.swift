import SwiftUI

@main
struct SnaptextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar–only app: no windows. All UI lives in the status item.
        Settings { EmptyView() }
    }
}
