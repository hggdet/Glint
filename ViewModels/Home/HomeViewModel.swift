import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case empty
        case failed
    }

    private enum PostMutation {
        case like
        case save
    }

    private(set) var state: LoadState = .loading
    private(set) var posts: [GlintPost] = []
    private(set) var stories: [GlintStoryFeedItem] = []
    private(set) var authorsByID: [UUID: GlintUser] = [:]
    private(set) var currentUser: GlintUser?
    private(set) var unreadNotificationCount = 0
    private(set) var errorKey: String?
    private(set) var paginationErrorKey: String?
    private(set) var isLoadingMore = false

    let viewerID: UUID
    private let services: GlintServices
    private let pageSize = 5
    private var nextPage: Int?

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
    }

    func load() async {
        state = .loading
        errorKey = nil
        paginationErrorKey = nil
        do {
            currentUser = try await services.users.fetchUser(id: viewerID, viewedBy: viewerID)
            if let currentUser { authorsByID[viewerID] = try await userForDisplay(currentUser) }
            async let storyLoad = services.stories.fetchStories(for: viewerID)
            async let unreadLoad = services.notifications.unreadCount(for: viewerID)
            let feed = try await services.posts.fetchFeed(for: viewerID, page: 0, pageSize: pageSize)
            let loadedStories = try await storyLoad
            let unreadCount = try await unreadLoad
            try await loadAuthors(for: feed.items)
            try await loadUsers(withIDs: Set(loadedStories.map { $0.story.authorID }))
            posts = feed.items
            nextPage = feed.nextPage
            stories = Array(loadedStories.prefix(4))
            unreadNotificationCount = unreadCount
            state = posts.isEmpty ? .empty : .ready
        } catch {
            state = .failed
            errorKey = messageKey(for: error)
        }
    }

    func refresh() async {
        errorKey = nil
        paginationErrorKey = nil
        do {
            async let storyLoad = services.stories.fetchStories(for: viewerID)
            async let unreadLoad = services.notifications.unreadCount(for: viewerID)
            let feed = try await services.posts.fetchFeed(for: viewerID, page: 0, pageSize: pageSize)
            let loadedStories = try await storyLoad
            let unreadCount = try await unreadLoad
            try await loadAuthors(for: feed.items)
            try await loadUsers(withIDs: Set(loadedStories.map { $0.story.authorID }))
            posts = feed.items
            nextPage = feed.nextPage
            stories = Array(loadedStories.prefix(4))
            unreadNotificationCount = unreadCount
            state = posts.isEmpty ? .empty : .ready
        } catch {
            errorKey = messageKey(for: error)
            if posts.isEmpty { state = .failed }
        }
    }

    func loadMoreIfNeeded(currentPost: GlintPost) async {
        guard currentPost.id == posts.last?.id, let nextPage, !isLoadingMore else { return }
        await loadNextPage(page: nextPage)
    }

    func retryLoadMore() async {
        guard let nextPage, !isLoadingMore else { return }
        await loadNextPage(page: nextPage)
    }

    private func loadNextPage(page: Int) async {
        paginationErrorKey = nil
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await services.posts.fetchFeed(for: viewerID, page: page, pageSize: pageSize)
            try await loadAuthors(for: result.items)
            posts.append(contentsOf: result.items)
            self.nextPage = result.nextPage
            paginationErrorKey = nil
        } catch {
            paginationErrorKey = messageKey(for: error)
        }
    }

    func toggleLike(for post: GlintPost) async {
        await updatePost(post, mutation: .like) {
            try await services.posts.toggleLike(postID: post.id, by: viewerID)
        }
    }

    func toggleSave(for post: GlintPost) async {
        await updatePost(post, mutation: .save) {
            try await services.posts.toggleSave(postID: post.id, by: viewerID)
        }
    }

    func createPost(caption: String, media: [PostMedia]) async throws {
        let post = try await services.posts.createPost(authorID: viewerID, caption: caption, media: media)
        if let currentUser { authorsByID[viewerID] = try await userForDisplay(currentUser) }
        posts.insert(post, at: 0)
        state = .ready
    }

    func didAddComment(to postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].commentCount += 1
    }

    func updateUnreadNotificationCount(_ count: Int) {
        unreadNotificationCount = max(0, count)
    }

    func block(authorID: UUID) async {
        do {
            try await services.users.block(userID: authorID, by: viewerID)
            posts.removeAll { $0.authorID == authorID }
            stories.removeAll { $0.story.authorID == authorID }
            authorsByID.removeValue(forKey: authorID)
            state = posts.isEmpty ? .empty : .ready
        } catch {
            errorKey = messageKey(for: error)
        }
    }

    func markStorySeen(_ item: GlintStoryFeedItem) async {
        guard !item.isSeen else { return }
        do {
            try await services.stories.markStorySeen(item.id, by: viewerID)
            if let index = stories.firstIndex(where: { $0.id == item.id }) {
                stories[index].isSeen = true
            }
        } catch {
            errorKey = messageKey(for: error)
        }
    }

    func reportPost(_ post: GlintPost, reason: ModerationReason, note: String?) async throws {
        let target: ModerationTarget = post.contentKind == .reel ? .reel(post.id) : .post(post.id)
        try await submitReport(target: target, reason: reason, note: note)
    }

    private func submitReport(target: ModerationTarget, reason: ModerationReason, note: String?) async throws {
        let report = ModerationReport(
            reporterID: viewerID,
            target: target,
            reason: reason,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        try await services.moderation.submitReport(report)
    }

    private func updatePost(
        _ post: GlintPost,
        mutation: PostMutation,
        operation: @MainActor () async throws -> GlintPost
    ) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let original = posts[index]
        var optimistic = original
        switch mutation {
        case .like:
            optimistic.isLiked.toggle()
            optimistic.likeCount = max(0, optimistic.likeCount + (optimistic.isLiked ? 1 : -1))
        case .save:
            optimistic.isSaved.toggle()
        }
        posts[index] = optimistic
        do {
            let updatedPost = try await operation()
            if let currentIndex = posts.firstIndex(where: { $0.id == post.id }) {
                posts[currentIndex] = updatedPost
            }
        } catch {
            if let currentIndex = posts.firstIndex(where: { $0.id == post.id }) {
                posts[currentIndex] = original
            }
            errorKey = messageKey(for: error)
        }
    }

    private func loadAuthors(for posts: [GlintPost]) async throws {
        try await loadUsers(withIDs: Set(posts.map(\.authorID)))
    }

    private func loadUsers(withIDs userIDs: Set<UUID>) async throws {
        for authorID in userIDs {
            let user = try await services.users.fetchUser(id: authorID, viewedBy: viewerID)
            authorsByID[authorID] = try await userForDisplay(user)
        }
    }

    private func userForDisplay(_ source: GlintUser) async throws -> GlintUser {
        var user = source
        guard source.id == viewerID || services.subscriptions is MockSubscriptionService else { return user }
        let tier = try await services.subscriptions.currentTier(for: source.id)
        if tier != .glintPlus {
            user.avatarShape = .circle
        }
        return user
    }

    private func messageKey(for error: Error) -> String {
        if error is GlintServiceError { return "home.error.load" }
        return "home.error.generic"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
