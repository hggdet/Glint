import Foundation

@MainActor
public final class MockStoryService: StoryService {
    private let userService: any UserService
    private let moderationService: any ModerationService
    private var stories: [GlintStory]
    private var seenStoryIDsByViewerID: [UUID: Set<UUID>] = [:]

    public init(userService: any UserService, moderationService: any ModerationService) {
        self.userService = userService
        self.moderationService = moderationService
        stories = MockData.stories
    }

    public func fetchStories(for viewerID: UUID) async throws -> [GlintStoryFeedItem] {
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        let followedUsers = try await userService.following(for: viewerID, viewedBy: viewerID)
        let followedIDs = Set(followedUsers.map(\.id))
        let viewerSeenIDs = seenStoryIDsByViewerID[viewerID, default: []]
        var feed: [GlintStoryFeedItem] = []

        for story in stories where story.expiresAt > .now && !hiddenIDs.contains(story.authorID) {
            guard story.authorID == viewerID || followedIDs.contains(story.authorID) else { continue }
            guard try await userService.canViewContent(of: story.authorID, by: viewerID) else { continue }
            feed.append(GlintStoryFeedItem(story: story, isSeen: viewerSeenIDs.contains(story.id)))
        }
        return feed.sorted { $0.story.createdAt < $1.story.createdAt }
    }

    public func createStory(authorID: UUID, media: PostMedia) async throws -> GlintStory {
        let decision = try await moderationService.checkBeforePublishing(
            .story(media: media),
            submittedBy: authorID
        )
        try requireAllowed(decision)
        let story = GlintStory(authorID: authorID, media: media)
        stories.insert(story, at: 0)
        return story
    }

    public func markStorySeen(_ storyID: UUID, by viewerID: UUID) async throws {
        guard let story = stories.first(where: { $0.id == storyID }), story.expiresAt > .now else {
            throw GlintServiceError.invalidInput("This story is not available to this viewer.")
        }
        guard try await userService.canViewContent(of: story.authorID, by: viewerID) else {
            throw GlintServiceError.invalidInput("This story is not available to this viewer.")
        }
        if story.authorID != viewerID {
            guard try await userService.isFollowing(userID: story.authorID, by: viewerID) else {
                throw GlintServiceError.invalidInput("This story is not available to this viewer.")
            }
        }
        seenStoryIDsByViewerID[viewerID, default: []].insert(storyID)
    }

    private func requireAllowed(_ decision: ModerationDecision) throws {
        switch decision {
        case .allow:
            return
        case .reject(let reason):
            throw GlintServiceError.moderationRejected(reason)
        case .review(let reason):
            throw GlintServiceError.moderationRequiresReview(reason)
        }
    }
}
