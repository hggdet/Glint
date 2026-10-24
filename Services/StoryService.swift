import Foundation

@MainActor
public protocol StoryService: AnyObject, Sendable {
    func fetchStories(for viewerID: UUID) async throws -> [GlintStoryFeedItem]
    func createStory(authorID: UUID, media: PostMedia) async throws -> GlintStory
    func markStorySeen(_ storyID: UUID, by viewerID: UUID) async throws
}
