import Foundation

public struct CredentialMatcher: Sendable {
    public init() {}

    public func score(_ credential: CredentialMetadata, for target: AutoTypeTarget) -> Int {
        var score = 0
        let title = target.windowTitle ?? ""

        if !title.isEmpty && title == credential.title {
            score = max(score, 1_500)
        }

        for rule in credential.matchRules {
            let value: String
            switch rule.type {
            case .windowTitle: value = target.windowTitle ?? ""
            case .applicationName: value = target.applicationName
            case .bundleIdentifier: value = target.bundleIdentifier ?? ""
            }

            switch rule.mode {
            case .exact where value == rule.pattern:
                score = max(score, 1_200)
            case .contains where value.contains(rule.pattern):
                score = max(score, 900)
            case .caseInsensitiveContains where value.localizedCaseInsensitiveContains(rule.pattern):
                score = max(score, 800)
            default:
                break
            }
        }

        if title.localizedCaseInsensitiveContains(credential.title) {
            score = max(score, 700)
        }

        // ponytail: O(n²) Levenshtein is enough for short window titles; replace only after ranking is measurable.
        score = max(score, Int(similarity(title, credential.title) * 600))
        score += Int(similarity(target.applicationName, credential.title) * 20)
        return score
    }

    public func sort(
        _ credentials: [CredentialMetadata],
        for target: AutoTypeTarget,
        query: String = ""
    ) -> [CredentialMetadata] {
        let filtered = query.isEmpty ? credentials : credentials.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.username.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted {
            let left = score($0, for: target)
            let right = score($1, for: target)
            return left == right ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending : left > right
        }
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let left = Array(lhs.lowercased())
        let right = Array(rhs.lowercased())
        var previous = Array(0...right.count)

        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            for (rightIndex, rightCharacter) in right.enumerated() {
                let substitution = previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                let insertion = current[rightIndex] + 1
                let deletion = previous[rightIndex + 1] + 1
                current.append(min(substitution, insertion, deletion))
            }
            previous = current
        }

        let distance = Double(previous[right.count])
        return 1 - distance / Double(max(left.count, right.count))
    }
}
