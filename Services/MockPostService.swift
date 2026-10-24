import Foundation

@MainActor
public final class MockPostService: PostService {
    private var posts: [GlintPost]
    private var comments: [GlintComment]
    private var likedByPostID: [UUID: Set<UUID>] = [:]
    private var savedByPostID: [UUID: Set<UUID>] = [:]
    private let userService: any UserService
    private let moderationService: any ModerationService
    private let notificationSink: (any MockNotificationEventSink)?

    public init(
        userService: any UserService,
        moderationService: any ModerationService,
        notificationSink: (any MockNotificationEventSink)? = nil
    ) {
        posts = MockData.posts
        comments = MockData.comments
        self.userService = userService
        self.moderationService = moderationService
        self.notificationSink = notificationSink
    }

    public func fetchFeed(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost> {
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        var feed: [GlintPost] = []
        for post in posts where !hiddenIDs.contains(post.authorID) {
            guard try await userService.canViewContent(of: post.authorID, by: viewerID) else { continue }
            guard try await userService.isFollowing(userID: post.authorID, by: viewerID) else { continue }
            feed.append(postForViewer(post, viewerID: viewerID))
        }
        return pageResult(feed.sorted { $0.createdAt > $1.createdAt }, page: page, pageSize: pageSize)
    }

    public func fetchPosts(by authorID: UUID, for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost> {
        guard try await userService.canViewContent(of: authorID, by: viewerID) else {
            throw GlintServiceError.userNotFound
        }
        let profilePosts = posts
            .filter { $0.authorID == authorID }
            .sorted { $0.createdAt > $1.createdAt }
            .map { postForViewer($0, viewerID: viewerID) }
        return pageResult(profilePosts, page: page, pageSize: pageSize)
    }

    public func fetchPost(_ postID: UUID, for viewerID: UUID) async throws -> GlintPost {
        let index = try await visiblePostIndex(postID, for: viewerID)
        return postForViewer(posts[index], viewerID: viewerID)
    }

    public func fetchExplorePosts(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost> {
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        var visiblePosts: [GlintPost] = []
        for post in posts where !hiddenIDs.contains(post.authorID) {
            guard try await userService.canViewContent(of: post.authorID, by: viewerID) else { continue }
            visiblePosts.append(postForViewer(post, viewerID: viewerID))
        }
        visiblePosts.sort { $0.likeCount > $1.likeCount }
        return pageResult(visiblePosts, page: page, pageSize: pageSize)
    }

    public func fetchReels(for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintPost> {
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        var reels: [GlintPost] = []
        for post in posts where post.contentKind == .reel && post.containsVideo && !hiddenIDs.contains(post.authorID) {
            guard try await userService.canViewContent(of: post.authorID, by: viewerID) else { continue }
            reels.append(postForViewer(post, viewerID: viewerID))
        }
        return pageResult(reels.sorted { $0.createdAt > $1.createdAt }, page: page, pageSize: pageSize)
    }

    public func canViewPost(_ postID: UUID, for viewerID: UUID) async throws -> Bool {
        guard let post = posts.first(where: { $0.id == postID }) else { return false }
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        guard !hiddenIDs.contains(post.authorID) else { return false }
        return try await userService.canViewContent(of: post.authorID, by: viewerID)
    }

    public func createPost(authorID: UUID, caption: String, media: [PostMedia]) async throws -> GlintPost {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !media.isEmpty else {
            throw GlintServiceError.invalidInput("Add text or media before posting.")
        }
        let decision = try await moderationService.checkBeforePublishing(
            .post(caption: text, media: media),
            submittedBy: authorID
        )
        try requireAllowed(decision)
        let post = GlintPost(authorID: authorID, caption: text, media: media)
        posts.insert(post, at: 0)
        return post
    }

    public func createReel(authorID: UUID, caption: String, media: [PostMedia]) async throws -> GlintPost {
        guard media.contains(where: { $0.kind == .video }) else {
            throw GlintServiceError.invalidInput("A Reel must include a video.")
        }
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let decision = try await moderationService.checkBeforePublishing(
            .reel(caption: text, media: media),
            submittedBy: authorID
        )
        try requireAllowed(decision)
        let post = GlintPost(authorID: authorID, caption: text, media: media, contentKind: .reel)
        posts.insert(post, at: 0)
        return post
    }

    public func toggleLike(postID: UUID, by viewerID: UUID) async throws -> GlintPost {
        let index = try await visiblePostIndex(postID, for: viewerID)
        var likers = likedByPostID[postID, default: []]
        if likers.contains(viewerID) {
            likers.remove(viewerID)
            posts[index].likeCount = max(0, posts[index].likeCount - 1)
        } else {
            likers.insert(viewerID)
            posts[index].likeCount += 1
            notificationSink?.recordNotification(
                recipientID: posts[index].authorID,
                event: .like,
                actorID: viewerID,
                destination: .post(postID)
            )
        }
        likedByPostID[postID] = likers
        return postForViewer(posts[index], viewerID: viewerID)
    }

    public func toggleSave(postID: UUID, by viewerID: UUID) async throws -> GlintPost {
        let index = try await visiblePostIndex(postID, for: viewerID)
        var savers = savedByPostID[postID, default: []]
        if savers.contains(viewerID) { savers.remove(viewerID) } else { savers.insert(viewerID) }
        savedByPostID[postID] = savers
        return postForViewer(posts[index], viewerID: viewerID)
    }

    public func fetchComments(postID: UUID, for viewerID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintComment> {
        _ = try await visiblePostIndex(postID, for: viewerID)
        var visibleComments: [GlintComment] = []
        for comment in comments where comment.postID == postID {
            guard try await userService.canViewContent(of: comment.authorID, by: viewerID) else { continue }
            visibleComments.append(comment)
        }
        visibleComments.sort { $0.createdAt < $1.createdAt }
        return pageResult(visibleComments, page: page, pageSize: pageSize)
    }

    public func addComment(postID: UUID, authorID: UUID, text: String) async throws -> GlintComment {
        let postIndex = try await visiblePostIndex(postID, for: authorID)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GlintServiceError.emptyComment }
        let decision = try await moderationService.checkBeforePublishing(
            .comment(text: trimmed),
            submittedBy: authorID
        )
        try requireAllowed(decision)
        let comment = GlintComment(postID: postID, authorID: authorID, text: trimmed)
        let recipientID = posts[postIndex].authorID
        let shouldNotifyRecipient = (try? await userService.canViewContent(of: authorID, by: recipientID)) == true
        comments.append(comment)
        posts[postIndex].commentCount += 1
        if shouldNotifyRecipient {
            notificationSink?.recordNotification(
                recipientID: recipientID,
                event: .comment(text: trimmed),
                actorID: authorID,
                destination: .post(postID)
            )
        }
        return comment
    }

    private func visiblePostIndex(_ postID: UUID, for viewerID: UUID) async throws -> Int {
        let hiddenIDs = try await userService.blockedUserIDs(for: viewerID)
        guard let index = posts.firstIndex(where: { $0.id == postID }),
              !hiddenIDs.contains(posts[index].authorID),
              try await userService.canViewContent(of: posts[index].authorID, by: viewerID) else {
            throw GlintServiceError.postNotFound
        }
        return index
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

    private func postForViewer(_ post: GlintPost, viewerID: UUID) -> GlintPost {
        var copy = post
        copy.isLiked = likedByPostID[post.id, default: []].contains(viewerID)
        copy.isSaved = savedByPostID[post.id, default: []].contains(viewerID)
        return copy
    }

    private func pageResult<Item: Sendable>(_ items: [Item], page: Int, pageSize: Int) -> PageResult<Item> {
        let safePage = max(0, page)
        let safeSize = max(1, pageSize)
        let start = min(safePage * safeSize, items.count)
        let end = min(start + safeSize, items.count)
        return PageResult(items: Array(items[start..<end]), nextPage: end < items.count ? safePage + 1 : nil)
    }
}
