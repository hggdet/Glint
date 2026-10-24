import Foundation

public enum GlintLanguage: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case english
    case arabic
}

public enum GlintAppearance: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case light
    case dark
}

public struct NotificationPreferences: Codable, Equatable, Sendable {
    public var likes: Bool
    public var comments: Bool
    public var newFollowers: Bool

    public init(likes: Bool = true, comments: Bool = true, newFollowers: Bool = true) {
        self.likes = likes
        self.comments = comments
        self.newFollowers = newFollowers
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var language: GlintLanguage
    public var appearance: GlintAppearance
    public var notificationPreferences: NotificationPreferences

    public init(
        language: GlintLanguage = .system,
        appearance: GlintAppearance = .system,
        notificationPreferences: NotificationPreferences = .init()
    ) {
        self.language = language
        self.appearance = appearance
        self.notificationPreferences = notificationPreferences
    }
}
