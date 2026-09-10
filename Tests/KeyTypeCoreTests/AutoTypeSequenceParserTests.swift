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
            try parser.parse("hello{TAB}world"),
            AutoTypeSequence(tokens: [.text("hello"), .tab, .text("world")])
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
    }
}
