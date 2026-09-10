import Foundation

public struct CredentialMetadata: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var username: String
    public var notes: String?
    public var matchRules: [MatchRule]
    public var autoTypeSequence: String

    public init(
        id: UUID = UUID(),
        title: String,
        username: String,
        notes: String? = nil,
        matchRules: [MatchRule] = [],
        autoTypeSequence: String = "{USERNAME}{TAB}{PASSWORD}{ENTER}"
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.notes = notes
        self.matchRules = matchRules
        self.autoTypeSequence = autoTypeSequence
    }
}
