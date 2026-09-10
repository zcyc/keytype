import SwiftUI

@main
struct KeyTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: appDelegate.state)
        } label: {
            Image(systemName: "key.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(state: appDelegate.state)
                .frame(width: 520, height: 420)
        }
    }
}
