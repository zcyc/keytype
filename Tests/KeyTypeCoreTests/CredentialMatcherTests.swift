import XCTest
@testable import KeyTypeCore

final class CredentialMatcherTests: XCTestCase {
    func testRanksCaseInsensitiveWindowMatchAboveTitleOnlyMatch() {
        let target = AutoTypeTarget(
            processIdentifier: 1,
            bundleIdentifier: "com.google.Chrome",
            applicationName: "Google Chrome",
            windowTitle: "SSH - PROD-DB-01"
        )
        let matching = CredentialMetadata(
            title: "prod-db-01",
            username: "root",
            matchRules: [MatchRule(type: .windowTitle, pattern: "prod-db-01")]
        )
        let unrelated = CredentialMetadata(title: "other", username: "root")

        let matcher = CredentialMatcher()
        XCTAssertGreaterThan(matcher.score(matching, for: target), matcher.score(unrelated, for: target))
    }

    func testSortsSearchResults() {
        let target = AutoTypeTarget(processIdentifier: 1, bundleIdentifier: nil, applicationName: "Terminal", windowTitle: "prod")
        let credentials = [
            CredentialMetadata(title: "other", username: "admin"),
            CredentialMetadata(title: "prod-db-01", username: "root")
        ]
        XCTAssertEqual(CredentialMatcher().sort(credentials, for: target).first?.title, "prod-db-01")
    }

    func testSupportsExactContainsAndCaseInsensitiveContains() {
        let target = AutoTypeTarget(processIdentifier: 1, bundleIdentifier: "com.example.Terminal", applicationName: "Terminal", windowTitle: "Prod")
        let matcher = CredentialMatcher()
        let exact = CredentialMetadata(title: "exact", username: "u", matchRules: [MatchRule(type: .windowTitle, mode: .exact, pattern: "Prod")])
        let contains = CredentialMetadata(title: "contains", username: "u", matchRules: [MatchRule(type: .windowTitle, mode: .contains, pattern: "ro")])
        let insensitive = CredentialMetadata(title: "insensitive", username: "u", matchRules: [MatchRule(type: .windowTitle, mode: .caseInsensitiveContains, pattern: "prod")])

        XCTAssertGreaterThan(matcher.score(exact, for: target), matcher.score(contains, for: target))
        XCTAssertGreaterThan(matcher.score(contains, for: target), 0)
        XCTAssertGreaterThan(matcher.score(insensitive, for: target), 0)
    }
}
