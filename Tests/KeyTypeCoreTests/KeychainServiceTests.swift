import XCTest
@testable import KeyTypeCore

final class KeychainServiceTests: XCTestCase {
    func testCredentialCRUDUsesSeparateMetadataAndPasswordItems() throws {
        let suffix = UUID().uuidString
        let service = KeychainService(
            metadataService: "com.keytype.tests.metadata.\(suffix)",
            passwordService: "com.keytype.tests.password.\(suffix)"
        )
        let credential = CredentialMetadata(
            title: "test",
            username: "root",
            customFields: ["EMAIL": "root@example.com", "FULL_NAME": "Jane Doe"],
            autoTypeSequence: "{FIELD:FULL_NAME}{TAB}{PASSWORD}"
        )
        defer { try? service.deleteCredential(id: credential.id) }

        try service.saveCredential(credential, password: "secret")
        XCTAssertEqual(try service.listCredentials(), [credential])
        XCTAssertEqual(try service.readPassword(id: credential.id), "secret")

        var updated = credential
        updated.title = "updated"
        try service.updateCredential(updated, password: "new-secret")
        XCTAssertEqual(try service.readMetadata(id: credential.id), updated)
        XCTAssertEqual(try service.readPassword(id: credential.id), "new-secret")

        try service.deleteCredential(id: credential.id)
        XCTAssertFalse(try service.credentialExists(id: credential.id))
    }

    func testDuplicateAndMissingItemsAreReported() throws {
        let suffix = UUID().uuidString
        let service = KeychainService(
            metadataService: "com.keytype.tests.metadata.\(suffix)",
            passwordService: "com.keytype.tests.password.\(suffix)"
        )
        let credential = CredentialMetadata(title: "test", username: "root")
        defer { try? service.deleteCredential(id: credential.id) }

        try service.saveCredential(credential, password: "secret")
        XCTAssertThrowsError(try service.saveCredential(credential, password: "secret")) { error in
            XCTAssertEqual(error as? KeychainError, .duplicateItem)
        }
        XCTAssertThrowsError(try service.readPassword(id: UUID())) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }
}
