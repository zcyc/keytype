import AppKit
import Combine
import KeyTypeCore
import SwiftUI

struct CustomFieldInput {
    let name: String
    let value: String
}

@MainActor
final class AppState: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var credentials: [CredentialMetadata] = []
    @Published var pickerSearch = ""
    @Published var selectedPickerCredentialID: UUID?
    @Published var message: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var hotkey: GlobalHotkey
    @Published var requireAuthentication: Bool {
        didSet { UserDefaults.standard.set(requireAuthentication, forKey: "requireAuthentication") }
    }
    @Published var authenticationGracePeriod: Int
    @Published var characterDelayMilliseconds: Int
    @Published var restoreFocusDelayMilliseconds: Int

    let keychain: KeychainService
    let authentication: AuthenticationService
    let accessibility: AccessibilityService
    let autoType: AutoTypeService

    private let matcher = CredentialMatcher()
    private let parser = AutoTypeSequenceParser()
    private let hotkeyService = GlobalHotkeyService()
    private let launchService = LaunchAtLoginService()
    private var pickerTarget: AutoTypeTarget?
    private var pickerWindow: NSPanel?
    private var pickerEventMonitor: Any?
    private var editorWindows: [NSWindow] = []
    private var autoTypeTask: Task<Void, Never>?
    private var sessionObservers: [NSObjectProtocol] = []

    var pickerCredentials: [CredentialMetadata] {
        guard let pickerTarget else {
            return credentials.filter(matchesPickerSearch).sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        return matcher.sort(credentials, for: pickerTarget, query: pickerSearch)
    }

    var isAutoTyping: Bool { autoTypeTask != nil }
    var isLocked: Bool { requireAuthentication && !authentication.isAuthenticated }

    override init() {
        keychain = KeychainService()
        authentication = AuthenticationService()
        accessibility = AccessibilityService()
        autoType = AutoTypeService(keychain: keychain, authentication: authentication, accessibility: accessibility)
        authenticationGracePeriod = Self.readInteger("authenticationGracePeriod", defaultValue: 30, bounds: 0...300)
        characterDelayMilliseconds = Self.readInteger("characterDelayMilliseconds", defaultValue: 10, bounds: 0...1_000)
        restoreFocusDelayMilliseconds = Self.readInteger("restoreFocusDelayMilliseconds", defaultValue: 200, bounds: 0...5_000)
        requireAuthentication = Self.readBool("requireAuthentication", defaultValue: true)
        hotkey = hotkeyService.hotkey
        launchAtLogin = launchService.isEnabled
        super.init()
        authentication.gracePeriod = TimeInterval(authenticationGracePeriod)
    }

    func start() {
        reloadCredentials()
        hotkeyService.onPress = { [weak self] in self?.handleHotkey() }
        startHotkeyIfPossible()
        let center = NotificationCenter.default
        sessionObservers = [
            center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.lock() }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.startHotkeyIfPossible() }
            }
        ]
    }

    func stop() {
        hotkeyService.stop()
        cancelAutoType()
        dismissPicker()
        for observer in sessionObservers { NotificationCenter.default.removeObserver(observer) }
        sessionObservers.removeAll()
    }

    func reloadCredentials() {
        do {
            credentials = try keychain.listCredentials().sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func addCredential() {
        openEditor(credential: nil)
    }

    func manageCredentials() {
        showWindow(
            CredentialListView(state: self),
            title: "Credentials",
            size: NSSize(width: 520, height: 420)
        )
    }

    func openSettings() {
        showWindow(
            SettingsView(state: self),
            title: "Settings",
            size: NSSize(width: 520, height: 420)
        )
    }

    func openPickerFromCurrentContext() {
        openPicker(target: accessibility.captureTarget())
    }

    func openPicker(target: AutoTypeTarget?) {
        guard autoTypeTask == nil else { return }

        if pickerWindow != nil { dismissPicker() }
        pickerTarget = target
        pickerSearch = ""
        selectedPickerCredentialID = pickerCredentials.first?.id
        showPickerWindow()
    }

    func confirmPickerSelection() {
        guard let selectedID = selectedPickerCredentialID,
              let credential = pickerCredentials.first(where: { $0.id == selectedID }) else { return }
        guard let target = pickerTarget ?? accessibility.captureTarget() else {
            showError("Unable to identify the target application.")
            return
        }
        guard accessibility.isTrusted else {
            dismissPicker()
            showAccessibilityRequirement()
            return
        }
        dismissPicker()
        startAutoType(credential: credential, target: target)
    }

    func movePickerSelection(by offset: Int) {
        let items = pickerCredentials
        guard !items.isEmpty else { return }
        guard let selectedID = selectedPickerCredentialID,
              let index = items.firstIndex(where: { $0.id == selectedID }) else {
            selectedPickerCredentialID = items.first?.id
            return
        }
        let nextIndex = min(max(index + offset, 0), items.count - 1)
        selectedPickerCredentialID = items[nextIndex].id
    }

    func ensurePickerSelection() {
        if !pickerCredentials.contains(where: { $0.id == selectedPickerCredentialID }) {
            selectedPickerCredentialID = pickerCredentials.first?.id
        }
    }

    func dismissPicker() {
        if let pickerEventMonitor { NSEvent.removeMonitor(pickerEventMonitor) }
        pickerEventMonitor = nil
        pickerWindow?.orderOut(nil)
        pickerWindow = nil
        pickerTarget = nil
        selectedPickerCredentialID = nil
        pickerSearch = ""
    }

    func cancelAutoType() {
        autoType.cancel()
        autoTypeTask?.cancel()
    }

    func unlock() {
        guard requireAuthentication else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await authentication.authenticate(reason: "Unlock KeyType")
                message = nil
                objectWillChange.send()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func lock() {
        cancelAutoType()
        authentication.lock()
        dismissPicker()
        message = nil
        objectWillChange.send()
    }

    func saveCredential(
        id: UUID,
        title: String,
        username: String,
        password: String,
        customFields inputs: [CustomFieldInput],
        notes: String,
        sequenceText: String,
        matchPattern: String
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            showError("A credential title is required.")
            return
        }
        do {
            let customFields = try Self.normalizedCustomFields(inputs)
            let sequence = try parser.parse(sequenceText)
            for token in sequence.tokens {
                guard case .field(let name) = token else { continue }
                guard customFields[name] != nil else {
                    throw AutoTypeSequenceError.missingField(name)
                }
            }
            let rules = matchPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? []
                : [MatchRule(type: .windowTitle, pattern: matchPattern.trimmingCharacters(in: .whitespacesAndNewlines))]
            let metadata = CredentialMetadata(
                id: id,
                title: trimmedTitle,
                username: username,
                customFields: customFields,
                notes: notes.isEmpty ? nil : notes,
                matchRules: rules,
                autoTypeSequence: sequenceText
            )

            if try keychain.credentialExists(id: id) {
                try keychain.updateCredential(metadata, password: password.isEmpty ? nil : password)
            } else {
                guard !password.isEmpty else {
                    showError("A password is required for a new credential.")
                    return
                }
                try keychain.saveCredential(metadata, password: password)
            }
            reloadCredentials()
            message = "Credential saved."
            closeCurrentWindow()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private static func normalizedCustomFields(_ inputs: [CustomFieldInput]) throws -> [String: String] {
        var fields: [String: String] = [:]
        for input in inputs {
            let rawName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name = AutoTypeSequenceParser.normalizedFieldName(rawName) else {
                throw AutoTypeSequenceError.invalidFieldName(rawName)
            }
            guard fields.updateValue(input.value, forKey: name) == nil else {
                throw AutoTypeSequenceError.duplicateField(name)
            }
        }
        return fields
    }

    private func matchesPickerSearch(_ credential: CredentialMetadata) -> Bool {
        guard !pickerSearch.isEmpty else { return true }
        return credential.title.localizedCaseInsensitiveContains(pickerSearch)
            || credential.username.localizedCaseInsensitiveContains(pickerSearch)
            || credential.customFields.contains {
                $0.key.localizedCaseInsensitiveContains(pickerSearch)
                    || $0.value.localizedCaseInsensitiveContains(pickerSearch)
            }
    }

    func deleteCredential(_ credential: CredentialMetadata) {
        let alert = NSAlert()
        alert.messageText = "Delete “\(credential.title)”?"
        alert.informativeText = "This removes the credential from KeyType and the macOS login Keychain."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try keychain.deleteCredential(id: credential.id)
            reloadCredentials()
            message = "Credential deleted."
        } catch {
            showError(error.localizedDescription)
        }
    }

    func openEditor(credential: CredentialMetadata?) {
        showWindow(
            CredentialEditorView(state: self, credential: credential),
            title: credential == nil ? "Add Credential" : "Edit Credential",
            size: NSSize(width: 560, height: 650)
        )
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchService.setEnabled(enabled)
            launchAtLogin = launchService.isEnabled
        } catch {
            launchAtLogin = launchService.isEnabled
            showError(error.localizedDescription)
        }
    }

    func updateAuthenticationGracePeriod(_ seconds: Int) {
        authenticationGracePeriod = seconds
        authentication.gracePeriod = TimeInterval(seconds)
        UserDefaults.standard.set(seconds, forKey: "authenticationGracePeriod")
    }

    func openAccessibilitySettings() {
        _ = accessibility.requestPermissionPrompt()
        accessibility.openSystemSettings()
    }

    func updateCharacterDelay(_ milliseconds: Int) {
        characterDelayMilliseconds = max(0, min(milliseconds, 1_000))
        UserDefaults.standard.set(characterDelayMilliseconds, forKey: "characterDelayMilliseconds")
    }

    func updateRestoreFocusDelay(_ milliseconds: Int) {
        restoreFocusDelayMilliseconds = max(0, min(milliseconds, 5_000))
        UserDefaults.standard.set(restoreFocusDelayMilliseconds, forKey: "restoreFocusDelayMilliseconds")
    }

    func beginHotkeyRecording() {
        hotkeyService.stop()
    }

    func updateHotkey(_ newHotkey: GlobalHotkey) {
        hotkeyService.setHotkey(newHotkey)
        hotkey = hotkeyService.hotkey
    }

    func resetHotkey() {
        hotkeyService.stop()
        hotkeyService.resetHotkey()
        hotkey = hotkeyService.hotkey
        startHotkeyIfPossible()
    }

    func endHotkeyRecording() {
        startHotkeyIfPossible()
    }

    private func handleHotkey() {
        guard autoTypeTask == nil else { return }
        openPicker(target: accessibility.captureTarget())
    }

    private func startHotkeyIfPossible() {
        guard hotkeyService.start() else {
            message = "Global shortcut is unavailable. It may already be in use by another app."
            return
        }
        if message == "Global shortcut is unavailable. It may already be in use by another app." {
            message = nil
        }
    }

    private func startAutoType(credential: CredentialMetadata, target: AutoTypeTarget) {
        guard autoTypeTask == nil else { return }
        do {
            let sequence = try parser.parse(credential.autoTypeSequence)
            let options = AutoTypeOptions(
                characterDelayMilliseconds: characterDelayMilliseconds,
                restoreFocusDelayMilliseconds: restoreFocusDelayMilliseconds
            )
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.autoTypeTask = nil }
                do {
                    try await self.autoType.execute(
                        sequence: sequence,
                        credential: credential,
                        target: target,
                        options: options,
                        requireAuthentication: self.requireAuthentication
                    )
                    self.message = nil
                } catch {
                    self.message = error.localizedDescription
                }
            }
            autoTypeTask = task
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showPickerWindow() {
        let size = NSSize(width: 560, height: 390)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Search Credential"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let hostingController = NSHostingController(rootView: CredentialPickerView(state: self))
        hostingController.sizingOptions = []
        panel.contentViewController = hostingController
        panel.delegate = self
        panel.setContentSize(size)
        panel.contentMinSize = size
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        pickerWindow = panel

        pickerEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53:
                self.dismissPicker()
                return nil
            case 36, 76:
                self.confirmPickerSelection()
                return nil
            case 126:
                self.movePickerSelection(by: -1)
                return nil
            case 125:
                self.movePickerSelection(by: 1)
                return nil
            default:
                return event
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if let pickerWindow, closingWindow === pickerWindow {
            dismissPicker()
        }
        editorWindows.removeAll { $0 === closingWindow }
    }

    private func showAccessibilityRequirement() {
        _ = accessibility.requestPermissionPrompt()
        let alert = NSAlert()
        alert.messageText = "Accessibility access is required"
        alert.informativeText = "KeyType needs Accessibility access to detect the active window, return focus to the target app, and type credentials using keyboard events."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            accessibility.openSystemSettings()
        }
        startHotkeyIfPossible()
    }

    private func showError(_ text: String) {
        message = text
        let alert = NSAlert()
        alert.messageText = "KeyType"
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func closeCurrentWindow() {
        NSApp.keyWindow?.close()
        editorWindows.removeAll { !$0.isVisible }
    }

    private func showWindow<Content: View>(_ content: Content, title: String, size: NSSize) {
        editorWindows.removeAll { !$0.isVisible }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        let hostingController = NSHostingController(rootView: content)
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        window.delegate = self
        window.setContentSize(size)
        window.contentMinSize = size
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        editorWindows.append(window)
    }

    private static func readInteger(_ key: String, defaultValue: Int, bounds: ClosedRange<Int>) -> Int {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return min(max(UserDefaults.standard.integer(forKey: key), bounds.lowerBound), bounds.upperBound)
    }

    private static func readBool(_ key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}
