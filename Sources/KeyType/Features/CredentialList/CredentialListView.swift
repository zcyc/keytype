import KeyTypeCore
import SwiftUI

struct CredentialListView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack {
            List {
                ForEach(state.credentials) { credential in
                    Button {
                        state.openEditor(credential: credential)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(credential.title)
                                    .font(.headline)
                                Text(credential.username.isEmpty ? "No username" : credential.username)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { state.deleteCredential(credential) }
                    }
                }
            }

            HStack {
                Button("Add Credential") { state.addCredential() }
                Spacer()
                Text("Passwords are never shown here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }
}
