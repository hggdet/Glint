import Foundation
import Observation

@MainActor
@Observable
final class OtherProfileViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed
    }

    private(set) var state: LoadState = .loading
    private(set) var user: GlintUser?
    private(set) var posts: [GlintPost] = []
    private(set) var followStatus: FollowRequestStatus?
    private(set) var canViewPosts = false
    private(set) var tier: GlintSubscriptionTier = .free
    private(set) var shouldGateAvatarShapeLocally = true
    private(set) var isChangingFollow = false
    private(set) var isBlocking = false
    private(set) var errorKey: String?
    private(set) var noticeKey: String?

    let viewerID: UUID
    let profileID: UUID
    private let services: GlintServices
    private var generation = UUID()

    init(profileID: UUID, viewerID: UUID, services: GlintServices) {
        self.profileID = profileID
        self.viewerID = viewerID
        self.services = services
    }

    func load() async {
        let currentGeneration = UUID()
        generation = currentGeneration
        state = .loading
        errorKey = nil
        do {
            async let loadedUser = services.users.fetchUser(id: profileID, viewedBy: viewerID)
            async let loadedStatus = services.users.followStatus(userID: profileID, by: viewerID)
            let (profile, status) = try await (loadedUser, loadedStatus)
            guard generation == currentGeneration else { return }
            user = profile
            followStatus = status
            if profileID == viewerID || services.subscriptions is MockSubscriptionService {
                tier = try await services.subscriptions.currentTier(for: profileID)
            } else {
                // Non-mock profile services must return an entitlement-authorized avatarShape.
                shouldGateAvatarShapeLocally = false
            }
            canViewPosts = try await services.users.canViewContent(of: profileID, by: viewerID)
            if canViewPosts {
                let result = try await services.posts.fetchPosts(by: profileID, for: viewerID, page: 0, pageSize: 100)
                guard generation == currentGeneration else { return }
                posts = result.items
            } else {
                posts = []
            }
            state = .ready
        } catch {
            guard generation == currentGeneration else { return }
            state = .failed
            errorKey = error is GlintServiceError ? "profile.other.error.unavailable" : "profile.other.error.generic"
        }
    }

    func retry() async { await load() }

    func refresh() async { await load() }

    func toggleFollow() async {
        guard !isChangingFollow, profileID != viewerID else { return }
        isChangingFollow = true
        errorKey = nil
        noticeKey = nil
        let oldStatus = followStatus
        let oldCount = user?.followerCount ?? 0

        if oldStatus == .accepted {
            followStatus = nil
            adjustFollowerCount(-1)
        } else if oldStatus == .pending {
            followStatus = nil
        } else {
            let predicted: FollowRequestStatus = (user?.isPrivate == true) ? .pending : .accepted
            followStatus = predicted
            if predicted == .accepted { adjustFollowerCount(1) }
        }

        defer { isChangingFollow = false }
        do {
            if oldStatus == .accepted || oldStatus == .pending {
                try await services.users.unfollow(userID: profileID, by: viewerID)
            } else {
                let newStatus = try await services.users.follow(userID: profileID, by: viewerID)
                followStatus = newStatus
                if newStatus != .accepted { user?.followerCount = oldCount }
            }
        } catch {
            followStatus = oldStatus
            user?.followerCount = oldCount
            errorKey = "profile.other.error.follow"
            return
        }

        if user?.isPrivate == true && followStatus != .accepted {
            canViewPosts = false
            posts = []
        }

        do {
            canViewPosts = try await services.users.canViewContent(of: profileID, by: viewerID)
            if canViewPosts {
                let result = try await services.posts.fetchPosts(by: profileID, for: viewerID, page: 0, pageSize: 100)
                posts = result.items
            } else {
                posts = []
            }
        } catch {
            errorKey = "profile.other.error.posts"
            if user?.isPrivate == true && followStatus != .accepted {
                canViewPosts = false
                posts = []
            }
        }
    }

    func block() async -> Bool {
        guard !isBlocking else { return false }
        isBlocking = true
        defer { isBlocking = false }
        do {
            try await services.users.block(userID: profileID, by: viewerID)
            user = nil
            posts = []
            canViewPosts = false
            return true
        } catch {
            errorKey = "profile.other.error.block"
            return false
        }
    }

    func report(_ reason: ModerationReason, note: String?) async throws {
        let report = ModerationReport(
            reporterID: viewerID,
            target: .user(profileID),
            reason: reason,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        try await services.moderation.submitReport(report)
    }

    private func adjustFollowerCount(_ amount: Int) {
        guard var user else { return }
        user.followerCount = max(0, user.followerCount + amount)
        self.user = user
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
