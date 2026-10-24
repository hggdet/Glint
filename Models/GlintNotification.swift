import Foundation

public enum GlintNotificationEvent: Codable, Equatable, Sendable {
    case like
    case comment(text: String)
    case newFollower

    /// Resolve this key through the active Arabic or English String Catalog.
    public var localizationKey: String {
        switch self {
        case .like: return "notification.like"
        case .comment(_): return "notification.comment"
        case .newFollower: return "notification.newFollower"
        }
    }

    /// Positional values for the localized format string, when the event has any.
    public var localizationArguments: [String] {
        switch self {
        case .like, .newFollower: return []
        case .comment(let text): return [text]
        }
    }
}

public enum GlintNotificationDestination: Codable, Equatable, Sendable {
    case post(UUID)
    case profile(UUID)
}

public struct GlintNotification: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var recipientID: UUID
    public var event: GlintNotificationEvent
    public var actorID: UUID
    public var destination: GlintNotificationDestination
    public var createdAt: Date
    public var isRead: Bool

    public init(
        id: UUID = UUID(),
        recipientID: UUID,
        event: GlintNotificationEvent,
        actorID: UUID,
        destination: GlintNotificationDestination,
        createdAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = id
        self.recipientID = recipientID
        self.event = event
        self.actorID = actorID
        self.destination = destination
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
