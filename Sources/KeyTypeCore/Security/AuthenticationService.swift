import Foundation
import LocalAuthentication

public enum AuthenticationError: Error, LocalizedError, Sendable {
    case unavailable(String)
    case failed
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return "Authentication is unavailable: \(reason)"
        case .failed: return "Authentication failed."
        case .cancelled: return "Authentication was cancelled."
        }
    }
}

@MainActor
public final class AuthenticationService {
    public var gracePeriod: TimeInterval
    private var lastAuthenticatedAt: Date?
    private var activeContext: LAContext?

    public init(gracePeriod: TimeInterval = 30) {
        self.gracePeriod = gracePeriod
    }

    public func authenticate(reason: String, required: Bool = true) async throws {
        guard required else { return }
        if gracePeriod > 0,
           let lastAuthenticatedAt,
           Date().timeIntervalSince(lastAuthenticatedAt) < gracePeriod {
            return
        }

        let context = LAContext()
        activeContext = context
        defer { activeContext = nil }
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            throw AuthenticationError.unavailable(availabilityError?.localizedDescription ?? "No system authentication method is available.")
        }

        do {
            let success = try await evaluate(context: context, reason: reason)
            guard success else { throw AuthenticationError.failed }
            lastAuthenticatedAt = Date()
        } catch let error as AuthenticationError {
            throw error
        } catch {
            if let localAuthenticationError = error as? LAError,
               [.userCancel, .systemCancel, .appCancel].contains(localAuthenticationError.code) {
                throw AuthenticationError.cancelled
            }
            throw AuthenticationError.failed
        }
    }

    public func lock() {
        lastAuthenticatedAt = nil
    }

    public func cancel() {
        activeContext?.invalidate()
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
