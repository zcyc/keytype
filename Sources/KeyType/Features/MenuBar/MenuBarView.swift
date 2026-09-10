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

struct MenuBarView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button("Search Credential") { state.openPickerFromCurrentContext() }
            Button("Add Credential") { state.addCredential() }
            Button("Manage Credentials") { state.manageCredentials() }
            Divider()
            Button(state.isAutoTyping ? "Cancel Auto-Type" : "Lock") {
                state.isAutoTyping ? state.cancelAutoType() : state.lock()
            }
            Button("Settings") { state.openSettings() }
            Divider()
            if let message = state.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(MenuBarButtonStyle())
        .padding(12)
        .frame(width: 240)
    }
}
