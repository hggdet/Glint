import Foundation

/// Canonical story content; read state is intentionally not stored on this shared model.
public struct GlintStory: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var authorID: UUID
    public var media: PostMedia
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        id: UUID = UUID(),
        authorID: UUID,
        media: PostMedia,
        createdAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.authorID = authorID
        self.media = media
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .hour, value: 24, to: createdAt) ?? createdAt.addingTimeInterval(86_400)
    }
}

/// Viewer-specific projection returned by StoryService; `isSeen` is never persisted on GlintStory.
public struct GlintStoryFeedItem: Identifiable, Codable, Equatable, Sendable {
    public var story: GlintStory
    public var isSeen: Bool

    public var id: UUID { story.id }

    public init(story: GlintStory, isSeen: Bool) {
        self.story = story
        self.isSeen = isSeen
    }
}
