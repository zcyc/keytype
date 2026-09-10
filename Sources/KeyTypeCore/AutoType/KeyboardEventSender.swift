import CoreGraphics
import Foundation

public enum SpecialKey: Sendable {
    case tab
    case enter
}

public enum KeyboardEventError: Error, LocalizedError, Sendable {
    case unavailable
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "KeyType could not create a keyboard event."
        case .cancelled: return "Auto-Type was cancelled."
        }
    }
}

@MainActor
public final class KeyboardEventSender {
    private let source: CGEventSource?

    public init() {
        source = CGEventSource(stateID: .hidSystemState)
    }

    public func send(
        text: String,
        characterDelayMilliseconds: Int,
        isCancelled: @escaping () -> Bool
    ) async throws {
        for character in text {
            guard !Task.isCancelled, !isCancelled() else { throw KeyboardEventError.cancelled }
            try sendUnicode(String(character))
            if characterDelayMilliseconds > 0 {
                try await Task.sleep(nanoseconds: UInt64(characterDelayMilliseconds) * 1_000_000)
            }
        }
    }

    public func press(_ key: SpecialKey) throws {
        let virtualKey: CGKeyCode
        switch key {
        case .tab: virtualKey = 48
        case .enter: virtualKey = 36
        }
        guard let source,
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            throw KeyboardEventError.unavailable
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func sendUnicode(_ text: String) throws {
        guard let source,
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw KeyboardEventError.unavailable
        }

        let units = Array(text.utf16)
        units.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
