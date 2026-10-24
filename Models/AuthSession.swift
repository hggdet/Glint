import Foundation

/// The mock service uses synthetic tokens stored by its injected SessionStore; the app demo
/// stores them in Keychain. Production must use provider-issued tokens and refresh them through
/// the authentication provider.
public struct AuthSession: Codable, Equatable, Sendable {
    public var userID: UUID
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date

    public init(userID: UUID, accessToken: String, refreshToken: String, expiresAt: Date) {
        self.userID = userID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool { expiresAt <= .now }
}
