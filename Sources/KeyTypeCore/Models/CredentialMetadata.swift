import Foundation

public struct CredentialMetadata: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var username: String
    public var customFields: [String: String]
    public var notes: String?
    public var matchRules: [MatchRule]
    public var autoTypeSequence: String

    public init(
        id: UUID = UUID(),
        title: String,
        username: String,
        customFields: [String: String] = [:],
        notes: String? = nil,
        matchRules: [MatchRule] = [],
        autoTypeSequence: String = "{USERNAME}{TAB}{PASSWORD}{ENTER}"
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.customFields = customFields
        self.notes = notes
        self.matchRules = matchRules
        self.autoTypeSequence = autoTypeSequence
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case username
        case customFields
        case notes
        case matchRules
        case autoTypeSequence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        username = try container.decode(String.self, forKey: .username)
        customFields = try container.decodeIfPresent([String: String].self, forKey: .customFields) ?? [:]
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        matchRules = try container.decodeIfPresent([MatchRule].self, forKey: .matchRules) ?? []
        autoTypeSequence = try container.decodeIfPresent(String.self, forKey: .autoTypeSequence)
            ?? "{USERNAME}{TAB}{PASSWORD}{ENTER}"
    }
}
