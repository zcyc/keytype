import Foundation

public enum AutoTypeSequenceError: Error, Equatable, LocalizedError, Sendable {
    case unknownToken(String)
    case invalidDelay(String)
    case malformedSequence

    public var errorDescription: String? {
        switch self {
        case .unknownToken(let token):
            return "Unknown auto-type token: \(token)"
        case .invalidDelay(let value):
            return "Invalid delay: \(value). Use an integer from 0 to 30000 milliseconds."
        case .malformedSequence:
            return "Malformed auto-type sequence: a token is missing its closing brace."
        }
    }
}

public struct AutoTypeSequenceParser: Sendable {
    public static let maximumDelayMilliseconds = 30_000

    public init() {}

    public func parse(_ input: String) throws -> AutoTypeSequence {
        var tokens: [AutoTypeToken] = []
        var cursor = input.startIndex

        func append(_ token: AutoTypeToken) {
            guard case .text(let text) = token,
                  case .text(let previous)? = tokens.last else {
                tokens.append(token)
                return
            }
            tokens[tokens.index(before: tokens.endIndex)] = .text(previous + text)
        }

        while cursor < input.endIndex {
            guard let openingBrace = input[cursor...].firstIndex(of: "{") else {
                append(.text(String(input[cursor...])))
                break
            }

            if openingBrace > cursor {
                append(.text(String(input[cursor..<openingBrace])))
            }

            guard let closingBrace = input[input.index(after: openingBrace)...].firstIndex(of: "}") else {
                throw AutoTypeSequenceError.malformedSequence
            }

            let rawToken = String(input[input.index(after: openingBrace)..<closingBrace])
            let token = try parseToken(rawToken)
            append(token)
            cursor = input.index(after: closingBrace)
        }

        return AutoTypeSequence(tokens: tokens)
    }

    private func parseToken(_ rawToken: String) throws -> AutoTypeToken {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        switch token {
        case "USERNAME": return .username
        case "PASSWORD": return .password
        case "TAB": return .tab
        case "ENTER": return .enter
        case let delay where delay.hasPrefix("DELAY "):
            let value = String(delay.dropFirst("DELAY ".count))
            guard !value.isEmpty, value.allSatisfy(\.isNumber),
                  let milliseconds = Int(value), milliseconds <= Self.maximumDelayMilliseconds else {
                throw AutoTypeSequenceError.invalidDelay(value)
            }
            return .delay(milliseconds: milliseconds)
        default:
            throw AutoTypeSequenceError.unknownToken(token)
        }
    }
}
