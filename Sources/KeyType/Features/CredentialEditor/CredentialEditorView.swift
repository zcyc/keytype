import KeyTypeCore
import SwiftUI

private enum SequencePreset: String, CaseIterable, Identifiable {
    case passwordOnly = "Password Only"
    case passwordEnter = "Password + Enter"
    case usernamePassword = "Username + Tab + Password"
    case usernamePasswordEnter = "Username + Tab + Password + Enter"
    case sshLogin = "Username + Enter + Password + Enter"
    case sshLoginNoFinalEnter = "Username + Enter + Password"
    case custom = "Custom"

    var id: String { rawValue }

    var value: String? {
        switch self {
        case .passwordOnly: return "{PASSWORD}"
        case .passwordEnter: return "{PASSWORD}{ENTER}"
        case .usernamePassword: return "{USERNAME}{TAB}{PASSWORD}"
        case .usernamePasswordEnter: return "{USERNAME}{TAB}{PASSWORD}{ENTER}"
        case .sshLogin: return "{USERNAME}{ENTER}{DELAY 500}{PASSWORD}{ENTER}"
        case .sshLoginNoFinalEnter: return "{USERNAME}{ENTER}{DELAY 500}{PASSWORD}"
        case .custom: return nil
        }
    }
}

private struct CustomFieldDraft: Identifiable {
    let id = UUID()
    var name: String
    var value: String
}

struct CredentialEditorView: View {
    @ObservedObject var state: AppState
    private let credentialID: UUID
    private let isExisting: Bool

    @State private var title: String
    @State private var username: String
    @State private var password = ""
    @State private var customFields: [CustomFieldDraft]
    @State private var notes: String
    @State private var sequence: String
    @State private var matchPattern: String
    @State private var preset: SequencePreset

    init(state: AppState, credential: CredentialMetadata?) {
        self.state = state
        credentialID = credential?.id ?? UUID()
        isExisting = credential != nil
        _title = State(initialValue: credential?.title ?? "")
        _username = State(initialValue: credential?.username ?? "")
        let existingFields = credential?.customFields ?? [:]
        _customFields = State(initialValue: existingFields.keys.sorted().map {
            CustomFieldDraft(name: $0, value: existingFields[$0] ?? "")
        })
        _notes = State(initialValue: credential?.notes ?? "")
        _sequence = State(initialValue: credential?.autoTypeSequence ?? "{PASSWORD}{ENTER}")
        _matchPattern = State(initialValue: credential?.matchRules.first(where: { $0.type == .windowTitle })?.pattern ?? "")
        _preset = State(initialValue: credential == nil ? .passwordEnter : .custom)
    }

    var body: some View {
        Form {
            Section("Credential") {
                TextField("Title", text: $title)
                TextField("Username", text: $username)
                SecureField(isExisting ? "Password (leave empty to keep current)" : "Password", text: $password)
            }

            Section("Custom Fields") {
                ForEach($customFields) { $field in
                    HStack {
                        TextField("Name", text: $field.name)
                            .frame(width: 150)
                        TextField("Value", text: $field.value)
                        Button {
                            customFields.removeAll { $0.id == field.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove field")
                    }
                }
                Button("Add Field") {
                    customFields.append(CustomFieldDraft(name: "", value: ""))
                }
            }

            Section("Auto-Type") {
                Picker("Preset", selection: $preset) {
                    ForEach(SequencePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .onChange(of: preset) { newPreset in
                    if let value = newPreset.value { sequence = value }
                }
                TextField(
                    "Sequence",
                    text: Binding(
                        get: { sequence },
                        set: {
                            sequence = $0
                            preset = .custom
                        }
                    )
                )
                    .font(.system(.body, design: .monospaced))
                Text("Tokens: {USERNAME} {PASSWORD} {FIELD:NAME} {TAB} {ENTER} {DELAY 500}. Spaces are typed literally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Window matching") {
                TextField("Window title contains (optional)", text: $matchPattern)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 70)
            }

            HStack {
                Spacer()
                Button("Cancel") { NSApp.keyWindow?.close() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func save() {
        state.saveCredential(
            id: credentialID,
            title: title,
            username: username,
            password: password,
            customFields: customFields.map { CustomFieldInput(name: $0.name, value: $0.value) },
            notes: notes,
            sequenceText: sequence,
            matchPattern: matchPattern
        )
    }
}
