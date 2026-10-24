import Foundation
import Security

@MainActor
public protocol AuthSessionStore: AnyObject {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func delete() throws
}

@MainActor
public final class InMemoryAuthSessionStore: AuthSessionStore {
    private var session: AuthSession?

    public init(session: AuthSession? = nil) {
        self.session = session
    }

    public func load() throws -> AuthSession? { session }
    public func save(_ session: AuthSession) throws { self.session = session }
    public func delete() throws { session = nil }
}

/// Stores the mock session in Keychain; production tokens must use the same protected storage boundary.
@MainActor
public final class KeychainAuthSessionStore: AuthSessionStore {
    private let service: String
    private let account: String

    public init(service: String = "com.glint.auth", account: String = "session") {
        self.service = service
        self.account = account
    }

    public func load() throws -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw GlintServiceError.sessionPersistenceFailed
        }
        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            throw GlintServiceError.sessionPersistenceFailed
        }
    }

    public func save(_ session: AuthSession) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            throw GlintServiceError.sessionPersistenceFailed
        }

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else {
            guard status == errSecSuccess else { throw GlintServiceError.sessionPersistenceFailed }
            return
        }

        var insertQuery = baseQuery
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insertQuery as CFDictionary, nil) == errSecSuccess else {
            throw GlintServiceError.sessionPersistenceFailed
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GlintServiceError.sessionPersistenceFailed
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
