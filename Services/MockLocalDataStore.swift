import Foundation

@MainActor
public protocol MockUserProfileStore: AnyObject {
    func loadProfiles() throws -> [GlintUser]
    func saveProfile(_ user: GlintUser) throws
}

@MainActor
public final class InMemoryMockUserProfileStore: MockUserProfileStore {
    private var profiles: [UUID: GlintUser] = [:]

    public init() {}

    public func loadProfiles() throws -> [GlintUser] { Array(profiles.values) }
    public func saveProfile(_ user: GlintUser) throws { profiles[user.id] = user }
}

@MainActor
public final class UserDefaultsMockUserProfileStore: MockUserProfileStore {
    private let defaults: UserDefaults
    private let key = "glint.mock.profiles.v2"
    private let legacyKey = "glint.mock.profiles.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadProfiles() throws -> [GlintUser] {
        guard let data = defaults.data(forKey: key) ?? defaults.data(forKey: legacyKey) else { return [] }
        do {
            let profiles = try JSONDecoder().decode([GlintUser].self, from: data)
            if defaults.data(forKey: key) == nil {
                let migrated = try JSONEncoder().encode(profiles)
                defaults.set(migrated, forKey: key)
                defaults.removeObject(forKey: legacyKey)
            }
            return profiles
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    public func saveProfile(_ user: GlintUser) throws {
        var profiles = try loadProfiles()
        if let index = profiles.firstIndex(where: { $0.id == user.id }) {
            profiles[index] = user
        } else {
            profiles.append(user)
        }
        do {
            defaults.set(try JSONEncoder().encode(profiles), forKey: key)
            defaults.removeObject(forKey: legacyKey)
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }
}

@MainActor
public protocol LegalConsentStore: AnyObject {
    func loadAll() throws -> [UUID: LegalConsent]
    func save(_ consent: LegalConsent, for userID: UUID) throws
    func delete(for userID: UUID) throws
}

@MainActor
public final class InMemoryLegalConsentStore: LegalConsentStore {
    private var consents: [UUID: LegalConsent] = [:]

    public init() {}

    public func loadAll() throws -> [UUID: LegalConsent] { consents }
    public func save(_ consent: LegalConsent, for userID: UUID) throws { consents[userID] = consent }
    public func delete(for userID: UUID) throws { consents.removeValue(forKey: userID) }
}

@MainActor
public final class UserDefaultsLegalConsentStore: LegalConsentStore {
    private let defaults: UserDefaults
    private let prefix = "glint.mock.legalConsent.v1."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadAll() throws -> [UUID: LegalConsent] {
        var result: [UUID: LegalConsent] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            guard let userID = UUID(uuidString: String(key.dropFirst(prefix.count))),
                  let data = value as? Data else { continue }
            do {
                result[userID] = try JSONDecoder().decode(LegalConsent.self, from: data)
            } catch {
                throw GlintServiceError.localDataPersistenceFailed
            }
        }
        return result
    }

    public func save(_ consent: LegalConsent, for userID: UUID) throws {
        do {
            defaults.set(try JSONEncoder().encode(consent), forKey: prefix + userID.uuidString)
        } catch {
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    public func delete(for userID: UUID) throws {
        defaults.removeObject(forKey: prefix + userID.uuidString)
    }
}

public struct MockSocialGraphState: Codable, Sendable {
    public var followingByUserID: [UUID: Set<UUID>]
    public var blockedByUserID: [UUID: Set<UUID>]
    public var followRequests: [FollowRequest]

    public init(
        followingByUserID: [UUID: Set<UUID>] = [:],
        blockedByUserID: [UUID: Set<UUID>] = [:],
        followRequests: [FollowRequest] = []
    ) {
        self.followingByUserID = followingByUserID
        self.blockedByUserID = blockedByUserID
        self.followRequests = followRequests
    }
}

@MainActor
public protocol MockSocialGraphStore: AnyObject {
    func load() throws -> MockSocialGraphState?
    func save(_ state: MockSocialGraphState) throws
}

@MainActor
public final class InMemoryMockSocialGraphStore: MockSocialGraphStore {
    private var state: MockSocialGraphState?
    public init() {}
    public func load() throws -> MockSocialGraphState? { state }
    public func save(_ state: MockSocialGraphState) throws { self.state = state }
}

@MainActor
public final class UserDefaultsMockSocialGraphStore: MockSocialGraphStore {
    private let defaults: UserDefaults
    private let key = "glint.mock.socialGraph.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() throws -> MockSocialGraphState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do { return try JSONDecoder().decode(MockSocialGraphState.self, from: data) }
        catch { throw GlintServiceError.localDataPersistenceFailed }
    }

    public func save(_ state: MockSocialGraphState) throws {
        do { defaults.set(try JSONEncoder().encode(state), forKey: key) }
        catch { throw GlintServiceError.localDataPersistenceFailed }
    }
}
