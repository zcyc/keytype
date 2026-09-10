import Foundation
import Security

public final class KeychainService: Sendable {
    public static let metadataService = "com.keytype.app.metadata"
    public static let passwordService = "com.keytype.app.password"

    private let metadataService: String
    private let passwordService: String

    public init(
        metadataService: String = KeychainService.metadataService,
        passwordService: String = KeychainService.passwordService
    ) {
        self.metadataService = metadataService
        self.passwordService = passwordService
    }

    public func saveCredential(_ metadata: CredentialMetadata, password: String) throws {
        let metadataData = try JSONEncoder().encode(metadata)
        do {
            try add(data: metadataData, service: metadataService, id: metadata.id)
            do {
                try add(data: Data(password.utf8), service: passwordService, id: metadata.id)
            } catch {
                try? delete(dataService: metadataService, id: metadata.id)
                throw error
            }
        } catch {
            throw error
        }
    }

    public func updateCredential(_ metadata: CredentialMetadata, password: String? = nil) throws {
        let metadataData = try JSONEncoder().encode(metadata)
        let oldMetadataData = try readData(service: metadataService, id: metadata.id)
        try update(data: metadataData, service: metadataService, id: metadata.id)

        guard let password else { return }
        do {
            try update(data: Data(password.utf8), service: passwordService, id: metadata.id)
        } catch {
            do {
                try update(data: oldMetadataData, service: metadataService, id: metadata.id)
            } catch {
                throw KeychainError.partialFailure
            }
            throw error
        }
    }

    public func deleteCredential(id: UUID) throws {
        var firstError: Error?
        for service in [metadataService, passwordService] {
            do {
                try delete(dataService: service, id: id)
            } catch KeychainError.itemNotFound {
                continue
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    public func readMetadata(id: UUID) throws -> CredentialMetadata {
        try JSONDecoder().decode(CredentialMetadata.self, from: readData(service: metadataService, id: id))
    }

    public func listCredentials() throws -> [CredentialMetadata] {
        var query = baseQuery(service: metadataService)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else { return [] }
        guard status == errSecSuccess else { throw KeychainError.from(status) }
        guard let attributes = result as? [[String: Any]] else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }

        return try attributes.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  let id = UUID(uuidString: account) else { return nil }
            return try readMetadata(id: id)
        }
    }

    public func readPassword(id: UUID) throws -> String {
        let data = try readData(service: passwordService, id: id)
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecDecode)
        }
        return password
    }

    public func credentialExists(id: UUID) -> Bool {
        (try? readData(service: metadataService, id: id)) != nil
    }

    private func add(data: Data, service: String, id: UUID) throws {
        var query = baseQuery(service: service, id: id)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.from(status) }
    }

    private func update(data: Data, service: String, id: UUID) throws {
        let query = baseQuery(service: service, id: id)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.from(status) }
    }

    private func delete(dataService service: String, id: UUID) throws {
        let status = SecItemDelete(baseQuery(service: service, id: id) as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.from(status) }
    }

    private func readData(service: String, id: UUID) throws -> Data {
        var query = baseQuery(service: service, id: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw KeychainError.from(status) }
        guard let data = result as? Data else { throw KeychainError.unexpectedStatus(errSecDecode) }
        return data
    }

    private func baseQuery(service: String, id: UUID? = nil) -> [String: Any] {
        // ponytail: use the login Keychain so ad-hoc builds need no entitlement; revisit synchronized/Data Protection storage only with entitlement-backed signing.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let id {
            query[kSecAttrAccount as String] = id.uuidString
        }
        return query
    }
}
