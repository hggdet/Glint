import Foundation
import Observation

@MainActor
@Observable
final class ReelsViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case empty
        case failed
    }

    private enum Mutation {
        case like
    }

    private(set) var state: LoadState = .loading
    private(set) var reels: [GlintPost] = []
    private(set) var authorsByID: [UUID: GlintUser] = [:]
    private(set) var errorKey: String?
    private(set) var paginationErrorKey: String?
    private(set) var isLoadingMore = false

    let viewerID: UUID
    private let services: GlintServices
    private let pageSize = 2
    private var nextPage: Int?
    private var loadGeneration = UUID()
    private var paginationGeneration = UUID()

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
    }

    func load() async {
        let generation = UUID()
        loadGeneration = generation
        paginationGeneration = UUID()
        isLoadingMore = false
        nextPage = nil
        state = .loading
        errorKey = nil
        paginationErrorKey = nil
        do {
            let page = try await services.posts.fetchReels(for: viewerID, page: 0, pageSize: pageSize)
            guard loadGeneration == generation else { return }
            try await loadAuthors(for: page.items)
            guard loadGeneration == generation else { return }
            reels = page.items
            nextPage = page.nextPage
            state = reels.isEmpty ? .empty : .ready
        } catch {
            guard loadGeneration == generation else { return }
            state = .failed
            errorKey = messageKey(for: error)
        }
    }

    func loadMoreIfNeeded(currentIndex: Int) async {
        guard currentIndex == reels.count - 1, let nextPage, !isLoadingMore else { return }
        await loadNextPage(nextPage)
    }

    func retryLoadMore() async {
        guard let nextPage, !isLoadingMore else { return }
        await loadNextPage(nextPage)
    }

    private func loadNextPage(_ pageNumber: Int) async {
        let generation = paginationGeneration
        paginationErrorKey = nil
        isLoadingMore = true
        defer {
            if paginationGeneration == generation { isLoadingMore = false }
        }
        do {
            let page = try await services.posts.fetchReels(for: viewerID, page: pageNumber, pageSize: pageSize)
            guard paginationGeneration == generation, state == .ready else { return }
            try await loadAuthors(for: page.items)
            guard paginationGeneration == generation else { return }
            reels.append(contentsOf: page.items)
            nextPage = page.nextPage
        } catch {
            guard paginationGeneration == generation else { return }
            paginationErrorKey = messageKey(for: error)
        }
    }

    func toggleLike(for reel: GlintPost) async {
        await updateReel(reel, mutation: .like) {
            try await services.posts.toggleLike(postID: reel.id, by: viewerID)
        }
    }

    func didAddComment(to reelID: UUID) {
        guard let index = reels.firstIndex(where: { $0.id == reelID }) else { return }
        reels[index].commentCount += 1
    }

    func report(_ reel: GlintPost, reason: ModerationReason, note: String?) async throws {
        let report = ModerationReport(
            reporterID: viewerID,
            target: .reel(reel.id),
            reason: reason,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        try await services.moderation.submitReport(report)
    }

    private func updateReel(
        _ reel: GlintPost,
        mutation: Mutation,
        operation: @MainActor () async throws -> GlintPost
    ) async {
        guard let index = reels.firstIndex(where: { $0.id == reel.id }) else { return }
        let previous = reels[index]
        var optimistic = previous
        if case .like = mutation {
            optimistic.isLiked.toggle()
            optimistic.likeCount = max(0, optimistic.likeCount + (optimistic.isLiked ? 1 : -1))
        }
        reels[index] = optimistic
        do {
            let updated = try await operation()
            if let currentIndex = reels.firstIndex(where: { $0.id == reel.id }) {
                reels[currentIndex] = updated
            }
        } catch {
            if let currentIndex = reels.firstIndex(where: { $0.id == reel.id }) {
                reels[currentIndex] = previous
            }
            errorKey = messageKey(for: error)
        }
    }

    private func loadAuthors(for reels: [GlintPost]) async throws {
        for authorID in Set(reels.map(\.authorID)) {
            var user = try await services.users.fetchUser(id: authorID, viewedBy: viewerID)
            guard services.subscriptions is MockSubscriptionService || authorID == viewerID else {
                authorsByID[authorID] = user
                continue
            }
            let tier = try await services.subscriptions.currentTier(for: authorID)
            if tier != .glintPlus {
                user.avatarShape = .circle
            }
            authorsByID[authorID] = user
        }
    }

    private func messageKey(for error: Error) -> String {
        if error is GlintServiceError { return "reels.error.load" }
        return "reels.error.generic"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
