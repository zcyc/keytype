import XCTest
@testable import KeyTypeCore

final class AutoTypeSequenceParserTests: XCTestCase {
    private let parser = AutoTypeSequenceParser()

    func testParsesSSHSequence() throws {
        XCTAssertEqual(
            try parser.parse("{USERNAME}{ENTER}{DELAY 500}{PASSWORD}{ENTER}"),
            AutoTypeSequence(tokens: [.username, .enter, .delay(milliseconds: 500), .password, .enter])
        )
    }

    func testParsesTextAndSpecialTokens() throws {
        XCTAssertEqual(
            try parser.parse("hello {TAB}{FIELD:full_name}"),
            AutoTypeSequence(tokens: [.text("hello "), .tab, .field("FULL_NAME")])
        )
    }

    func testPreservesSpacesInText() throws {
        XCTAssertEqual(
            try parser.parse("{FIELD:FULL_NAME} {PASSWORD}"),
            AutoTypeSequence(tokens: [.field("FULL_NAME"), .text(" "), .password])
        )
    }

    func testRejectsInvalidInput() {
        XCTAssertThrowsError(try parser.parse("{DELAY abc}")) { error in
            XCTAssertEqual(error as? AutoTypeSequenceError, .invalidDelay("abc"))
        }
        XCTAssertThrowsError(try parser.parse("{UNKNOWN}")) { error in
            XCTAssertEqual(error as? AutoTypeSequenceError, .unknownToken("UNKNOWN"))
        }
        XCTAssertThrowsError(try parser.parse("{")) { error in
            XCTAssertEqual(error as? AutoTypeSequenceError, .malformedSequence)
        }
        XCTAssertThrowsError(try parser.parse("{FIELD:full name}")) { error in
            XCTAssertEqual(error as? AutoTypeSequenceError, .invalidFieldName("full name"))
        }
    }
}
