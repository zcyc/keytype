import Foundation
import Security

public enum KeychainError: Error, Equatable, LocalizedError, Sendable {
    case duplicateItem
    case itemNotFound
    case authenticationFailed
    case interactionNotAllowed
    case partialFailure
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .duplicateItem: return "This credential already exists."
        case .itemNotFound: return "The credential was not found in Keychain."
        case .authenticationFailed: return "Keychain authentication failed."
        case .interactionNotAllowed: return "Keychain interaction is not allowed right now."
        case .partialFailure: return "The credential changed only partially. Please review it before retrying."
        case .unexpectedStatus(let status): return "Keychain error (OSStatus \(status))."
        }
    }

    static func from(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecDuplicateItem: return .duplicateItem
        case errSecItemNotFound: return .itemNotFound
        case errSecAuthFailed: return .authenticationFailed
        case errSecInteractionNotAllowed: return .interactionNotAllowed
        default: return .unexpectedStatus(status)
        }
    }
}
