import AppKit
import Foundation

public struct AutoTypeOptions: Sendable {
    public var characterDelayMilliseconds: Int
    public var restoreFocusDelayMilliseconds: Int

    public init(characterDelayMilliseconds: Int = 10, restoreFocusDelayMilliseconds: Int = 200) {
        self.characterDelayMilliseconds = max(0, characterDelayMilliseconds)
        self.restoreFocusDelayMilliseconds = max(0, restoreFocusDelayMilliseconds)
    }
}

public enum AutoTypeState: Equatable, Sendable {
    case idle
    case preparing
    case typing
}

public enum AutoTypeError: Error, LocalizedError, Sendable {
    case alreadyRunning
    case accessibilityRequired
    case targetUnavailable
    case targetChanged
    case passwordUnavailable
    case missingField(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning: return "Auto-Type is already running."
        case .accessibilityRequired: return "KeyType needs Accessibility access to type credentials."
        case .targetUnavailable: return "The original target application is no longer available."
        case .targetChanged: return "Auto-Type stopped because the active application changed."
        case .passwordUnavailable: return "The credential password could not be prepared."
        case .missingField(let name): return "Custom field is not defined: \(name)"
        case .cancelled: return "Auto-Type was cancelled."
        }
    }
}

@MainActor
public final class AutoTypeService {
    public private(set) var state: AutoTypeState = .idle

    private let keychain: KeychainService
    private let authentication: AuthenticationService
    private let accessibility: AccessibilityService
    private let sender: KeyboardEventSender
    private var cancellationRequested = false
    private var escapeMonitor: Any?

    public init(
        keychain: KeychainService,
        authentication: AuthenticationService,
        accessibility: AccessibilityService,
        sender: KeyboardEventSender? = nil
    ) {
        self.keychain = keychain
        self.authentication = authentication
        self.accessibility = accessibility
        self.sender = sender ?? KeyboardEventSender()
    }

    public func cancel() {
        cancellationRequested = true
    }

    public func execute(
        sequence: AutoTypeSequence,
        credential: CredentialMetadata,
        target: AutoTypeTarget,
        options: AutoTypeOptions,
        requireAuthentication: Bool = true
    ) async throws {
        guard state == .idle else { throw AutoTypeError.alreadyRunning }
        for token in sequence.tokens {
            guard case .field(let name) = token else { continue }
            guard credential.customFields[name] != nil else {
                throw AutoTypeError.missingField(name)
            }
        }
        state = .preparing
        cancellationRequested = false
        installEscapeMonitor()
        defer {
            removeEscapeMonitor()
            state = .idle
            cancellationRequested = false
        }

        do {
            try checkCancellation()
            guard accessibility.isTrusted else { throw AutoTypeError.accessibilityRequired }
            try await authentication.authenticate(
                reason: "Authenticate to Auto-Type this credential",
                required: requireAuthentication
            )
            try checkCancellation()

            var password: String? = nil
            if sequence.tokens.contains(where: { token in
                if case .password = token { return true }
                return false
            }) {
                // Read before returning focus so first-use Keychain authorization cannot interrupt typing.
                password = try keychain.readPassword(id: credential.id)
            }

            guard accessibility.activate(target) else { throw AutoTypeError.targetUnavailable }
            try await sleep(milliseconds: options.restoreFocusDelayMilliseconds)
            try verifyTarget(target)
            state = .typing

            for token in sequence.tokens {
                try verifyTarget(target)
                switch token {
                case .username:
                    try await sender.send(text: credential.username, characterDelayMilliseconds: options.characterDelayMilliseconds, isCancelled: shouldCancel)
                case .password:
                    guard let password else { throw AutoTypeError.passwordUnavailable }
                    try await sender.send(text: password, characterDelayMilliseconds: options.characterDelayMilliseconds, isCancelled: shouldCancel)
                case .field(let name):
                    guard let value = credential.customFields[name] else {
                        throw AutoTypeError.missingField(name)
                    }
                    try await sender.send(text: value, characterDelayMilliseconds: options.characterDelayMilliseconds, isCancelled: shouldCancel)
                case .tab:
                    try sender.press(.tab)
                case .enter:
                    try sender.press(.enter)
                case .delay(let milliseconds):
                    try await sleep(milliseconds: milliseconds)
                case .text(let text):
                    try await sender.send(text: text, characterDelayMilliseconds: options.characterDelayMilliseconds, isCancelled: shouldCancel)
                }
            }
        } catch is CancellationError {
            throw AutoTypeError.cancelled
        } catch KeyboardEventError.cancelled {
            throw AutoTypeError.cancelled
        }
    }

    private func shouldCancel() -> Bool {
        cancellationRequested || Task.isCancelled
    }

    private func checkCancellation() throws {
        guard !shouldCancel() else { throw AutoTypeError.cancelled }
    }

    private func verifyTarget(_ target: AutoTypeTarget) throws {
        try checkCancellation()
        guard accessibility.isTrusted else { throw AutoTypeError.accessibilityRequired }
        guard accessibility.isFrontmost(target) else { throw AutoTypeError.targetChanged }
    }

    private func sleep(milliseconds: Int) async throws {
        var remaining = milliseconds
        while remaining > 0 {
            try checkCancellation()
            let step = min(remaining, 50)
            try await Task.sleep(nanoseconds: UInt64(step) * 1_000_000)
            remaining -= step
        }
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }
}
