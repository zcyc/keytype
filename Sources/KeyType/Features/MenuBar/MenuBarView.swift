import KeyTypeCore
import SwiftUI

private struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.1) : .clear)
            }
    }
}

private struct MenuBarAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(title)
            }
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            MenuBarAction(title: "Search Credential", systemImage: "magnifyingglass") {
                state.openPickerFromCurrentContext()
            }
            MenuBarAction(title: "Add Credential", systemImage: "plus.circle") {
                state.addCredential()
            }
            MenuBarAction(title: "Manage Credentials", systemImage: "list.bullet.rectangle") {
                state.manageCredentials()
            }
            Divider()
            MenuBarAction(
                title: state.isAutoTyping ? "Cancel Auto-Type" : "Lock",
                systemImage: state.isAutoTyping ? "xmark.circle" : "lock.fill"
            ) {
                state.isAutoTyping ? state.cancelAutoType() : state.lock()
            }
            MenuBarAction(title: "Settings", systemImage: "gearshape") {
                state.openSettings()
            }
            Divider()
            if let message = state.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            MenuBarAction(title: "Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .buttonStyle(MenuBarButtonStyle())
        .padding(12)
        .frame(width: 240)
    }
}
