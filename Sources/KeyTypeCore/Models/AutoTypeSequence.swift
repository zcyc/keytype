import Foundation

public enum AutoTypeToken: Equatable, Sendable {
    case username
    case password
    case tab
    case enter
    case delay(milliseconds: Int)
    case text(String)
}

public struct AutoTypeSequence: Equatable, Sendable {
    public let tokens: [AutoTypeToken]

    public init(tokens: [AutoTypeToken]) {
        self.tokens = tokens
    }

    public static func parse(_ input: String) throws -> AutoTypeSequence {
        try AutoTypeSequenceParser().parse(input)
    }
}
