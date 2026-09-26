import Foundation
import LocalAuthentication

public enum AuthenticationError: Error, LocalizedError, Sendable {
    case unavailable(String)
    case failed
    case cancelled
    case alreadyInProgress

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return "Authentication is unavailable: \(reason)"
        case .failed: return "Authentication failed."
        case .cancelled: return "Authentication was cancelled."
        case .alreadyInProgress: return "Authentication is already in progress."
        }
    }
}

@MainActor
public final class AuthenticationService {
    public var gracePeriod: TimeInterval
    private var lastAuthenticatedAt: Date?
    private var activeContext: LAContext?
    private var authenticationGeneration = 0

    public var isAuthenticated: Bool {
        guard gracePeriod > 0, let lastAuthenticatedAt else { return false }
        return Date().timeIntervalSince(lastAuthenticatedAt) < gracePeriod
    }

    public init(gracePeriod: TimeInterval = 30) {
        self.gracePeriod = gracePeriod
    }

    public func authenticate(reason: String, required: Bool = true) async throws {
        guard required else { return }
        if isAuthenticated { return }
        guard activeContext == nil else { throw AuthenticationError.alreadyInProgress }

        let context = LAContext()
        // Ignore a prompt result if lock or cancel occurs while authentication is suspended.
        let generation = authenticationGeneration
        activeContext = context
        defer {
            if activeContext === context { activeContext = nil }
        }
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            throw AuthenticationError.unavailable(availabilityError?.localizedDescription ?? "No system authentication method is available.")
        }

        do {
            let success = try await evaluate(context: context, reason: reason)
            guard generation == authenticationGeneration else { throw AuthenticationError.cancelled }
            guard success else { throw AuthenticationError.failed }
            lastAuthenticatedAt = Date()
        } catch {
            guard generation == authenticationGeneration else { throw AuthenticationError.cancelled }
            if let authenticationError = error as? AuthenticationError {
                throw authenticationError
            }
            if let localAuthenticationError = error as? LAError,
               [.userCancel, .systemCancel, .appCancel].contains(localAuthenticationError.code) {
                throw AuthenticationError.cancelled
            }
            throw AuthenticationError.failed
        }
    }

    public func lock() {
        cancel()
        lastAuthenticatedAt = nil
    }

    public func cancel() {
        authenticationGeneration += 1
        let context = activeContext
        activeContext = nil
        context?.invalidate()
    }

    private func evaluate(context: LAContext, reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
