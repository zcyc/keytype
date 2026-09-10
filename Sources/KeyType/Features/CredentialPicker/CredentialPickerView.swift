import KeyTypeCore
import SwiftUI

struct CredentialPickerView: View {
    @ObservedObject var state: AppState
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search credentials", text: $state.pickerSearch)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onChange(of: state.pickerSearch) { _ in state.ensurePickerSelection() }

            if state.pickerCredentials.isEmpty {
                VStack(spacing: 8) {
                    Text(state.credentials.isEmpty ? "No credentials yet." : "No matching credentials.")
                        .foregroundStyle(.secondary)
                    if state.credentials.isEmpty {
                        Button("Add Credential") {
                            state.dismissPicker()
                            state.addCredential()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(state.pickerCredentials) { credential in
                            Button {
                                state.selectedPickerCredentialID = credential.id
                                state.confirmPickerSelection()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(credential.title)
                                            .font(.headline)
                                        Text(credential.username)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if state.selectedPickerCredentialID == credential.id {
                                        Image(systemName: "return")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(state.selectedPickerCredentialID == credential.id ? Color.accentColor.opacity(0.18) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Text("↑ ↓ select · Return auto-type · Esc cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { state.dismissPicker() }
            }
        }
        .padding(14)
        .onAppear {
            searchFocused = true
            state.ensurePickerSelection()
        }
        .onExitCommand { state.dismissPicker() }
    }
}
