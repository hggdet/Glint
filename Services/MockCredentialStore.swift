import CryptoKit
import Foundation

public struct MockAccountCredential: Codable, Equatable, Sendable {
    public let userID: UUID
    public let salt: Data
    public let passwordDigest: Data

    public init(userID: UUID, salt: Data, passwordDigest: Data) {
        self.userID = userID
        self.salt = salt
        self.passwordDigest = passwordDigest
    }

    public static func make(userID: UUID, password: String) -> MockAccountCredential {
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let digest = digest(password: password, salt: salt)
        return MockAccountCredential(userID: userID, salt: salt, passwordDigest: digest)
    }

    public func matches(password: String) -> Bool {
        let candidate = Self.digest(password: password, salt: salt)
        guard candidate.count == passwordDigest.count else { return false }
        let difference = zip(candidate, passwordDigest).reduce(UInt8(0)) { partial, pair in
            partial | (pair.0 ^ pair.1)
        }
        return difference == 0
    }

    private static func digest(password: String, salt: Data) -> Data {
        var input = Data(password.utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }
}

@MainActor
public protocol MockCredentialStore: AnyObject {
    func loadAll() throws -> [String: MockAccountCredential]
    func save(_ credential: MockAccountCredential, for normalizedEmail: String) throws
    func delete(for normalizedEmail: String) throws
}

@MainActor
public final class InMemoryMockCredentialStore: MockCredentialStore {
    private var credentials: [String: MockAccountCredential] = [:]

    public init() {}

    public func loadAll() throws -> [String: MockAccountCredential] { credentials }
    public func save(_ credential: MockAccountCredential, for normalizedEmail: String) throws {
        credentials[normalizedEmail] = credential
    }
    public func delete(for normalizedEmail: String) throws { credentials.removeValue(forKey: normalizedEmail) }
}

@MainActor
public final class UserDefaultsMockCredentialStore: MockCredentialStore {
    private let defaults: UserDefaults
    private let key = "glint.mock.credentials.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadAll() throws -> [String: MockAccountCredential] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([String: MockAccountCredential].self, from: data)
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    public func save(_ credential: MockAccountCredential, for normalizedEmail: String) throws {
        var credentials = try loadAll()
        credentials[normalizedEmail] = credential
        do {
            defaults.set(try JSONEncoder().encode(credentials), forKey: key)
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    public func delete(for normalizedEmail: String) throws {
        var credentials = try loadAll()
        credentials.removeValue(forKey: normalizedEmail)
        if credentials.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(credentials), forKey: key)
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }
}
