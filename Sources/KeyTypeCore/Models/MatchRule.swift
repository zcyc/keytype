import Foundation

public enum MatchRuleType: String, Codable, Sendable {
    case windowTitle
    case applicationName
    case bundleIdentifier
}

public enum MatchRuleMode: String, Codable, Sendable {
    case exact
    case contains
    case caseInsensitiveContains
}

public struct MatchRule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var type: MatchRuleType
    public var mode: MatchRuleMode
    public var pattern: String

    public init(
        id: UUID = UUID(),
        type: MatchRuleType,
        mode: MatchRuleMode = .caseInsensitiveContains,
        pattern: String
    ) {
        self.id = id
        self.type = type
        self.mode = mode
        self.pattern = pattern
    }
}
