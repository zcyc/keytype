import AppKit
import KeyTypeCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var isRecordingHotkey = false
    @State private var hotkeyError: String?
    @State private var accessibilityTrusted = false

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { state.launchAtLogin },
                        set: { state.setLaunchAtLogin($0) }
                    )
                )
            }

            Section("Permissions") {
                HStack(spacing: 8) {
                    Image(systemName: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                        Text(accessibilityTrusted ? "Granted" : "Required for Auto-Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !accessibilityTrusted {
                        Button("Open System Settings") {
                            state.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section("Security") {
                Toggle("Require authentication before Auto-Type", isOn: $state.requireAuthentication)
                Picker(
                    "Authentication grace period",
                    selection: Binding(
                        get: { state.authenticationGracePeriod },
                        set: { state.updateAuthenticationGracePeriod($0) }
                    )
                ) {
                    Text("Never").tag(0)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                    Text("5 minutes").tag(300)
                }
            }

            Section("Auto-Type") {
                Stepper(
                    "Character delay: \(state.characterDelayMilliseconds) ms",
                    value: Binding(
                        get: { state.characterDelayMilliseconds },
                        set: { state.updateCharacterDelay($0) }
                    ),
                    in: 0...1_000,
                    step: 5
                )
                Stepper(
                    "Restore focus delay: \(state.restoreFocusDelayMilliseconds) ms",
                    value: Binding(
                        get: { state.restoreFocusDelayMilliseconds },
                        set: { state.updateRestoreFocusDelay($0) }
                    ),
                    in: 0...5_000,
                    step: 50
                )
            }

            Section("Hotkey") {
                HStack(spacing: 8) {
                    HotkeyRecorder(
                        hotkey: state.hotkey,
                        isRecording: isRecordingHotkey,
                        onBeginRecording: {
                            hotkeyError = nil
                            isRecordingHotkey = true
                            state.beginHotkeyRecording()
                        },
                        onCancelRecording: {
                            isRecordingHotkey = false
                            state.endHotkeyRecording()
                        },
                        onKeyDown: recordHotkey
                    )
                    .frame(width: 180)

                    Button {
                        isRecordingHotkey = false
                        state.resetHotkey()
                        hotkeyError = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default")
                    .accessibilityLabel("Reset shortcut to default")
                }
                Text("Click the shortcut and press a key combination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hotkeyError {
                    Text(hotkeyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            while !Task.isCancelled {
                accessibilityTrusted = state.accessibility.isTrusted
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    break
                }
            }
        }
        .onDisappear {
            if isRecordingHotkey {
                isRecordingHotkey = false
                state.endHotkeyRecording()
            }
        }
    }

    private func recordHotkey(_ event: NSEvent) {
        var flags: CGEventFlags = []
        if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        guard !flags.isEmpty else {
            hotkeyError = "Use at least one modifier key."
            return
        }

        let keyLabel: String
        if let label = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !label.isEmpty {
            keyLabel = label
        } else {
            keyLabel = "Key " + String(event.keyCode)
        }
        state.updateHotkey(GlobalHotkey(keyCode: CGKeyCode(event.keyCode), requiredFlags: flags, keyLabel: keyLabel))
        isRecordingHotkey = false
        state.endHotkeyRecording()
    }
}

private struct HotkeyRecorder: NSViewRepresentable {
    let hotkey: GlobalHotkey
    let isRecording: Bool
    let onBeginRecording: () -> Void
    let onCancelRecording: () -> Void
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let button = HotkeyRecorderButton()
        button.onBeginRecording = onBeginRecording
        button.onCancelRecording = onCancelRecording
        button.onKeyDown = onKeyDown
        return button
    }

    func updateNSView(_ nsView: HotkeyRecorderButton, context: Context) {
        nsView.isRecording = isRecording
        nsView.title = isRecording ? "Press shortcut…" : hotkey.displayString
        nsView.onBeginRecording = onBeginRecording
        nsView.onCancelRecording = onCancelRecording
        nsView.onKeyDown = onKeyDown
        if isRecording && nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async { [weak nsView] in
                guard let nsView, nsView.isRecording else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class HotkeyRecorderButton: NSButton {
    var isRecording = false
    var onBeginRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onBeginRecording?()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            onCancelRecording?()
        } else {
            onKeyDown?(event)
        }
    }
}
