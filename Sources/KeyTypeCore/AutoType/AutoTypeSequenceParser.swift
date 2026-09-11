import Foundation

public enum AutoTypeSequenceError: Error, Equatable, LocalizedError, Sendable {
    case unknownToken(String)
    case invalidFieldName(String)
    case duplicateField(String)
    case missingField(String)
    case invalidDelay(String)
    case malformedSequence

    public var errorDescription: String? {
        switch self {
        case .unknownToken(let token):
            return "Unknown auto-type token: \(token)"
        case .invalidFieldName(let name):
            return "Invalid custom field name: \(name). Use letters, numbers, and underscores."
        case .duplicateField(let name):
            return "Duplicate custom field: \(name)"
        case .missingField(let name):
            return "Custom field is not defined: \(name)"
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

    public static func normalizedFieldName(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.utf8.allSatisfy({ $0 == 95 || $0 >= 48 && $0 <= 57 || $0 >= 65 && $0 <= 90 || $0 >= 97 && $0 <= 122 }) else {
            return nil
        }
        return name.uppercased()
    }

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
        case let field where field.hasPrefix("FIELD:"):
            let rawName = String(field.dropFirst("FIELD:".count))
            guard let name = Self.normalizedFieldName(rawName) else {
                throw AutoTypeSequenceError.invalidFieldName(rawName)
            }
            return .field(name)
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
