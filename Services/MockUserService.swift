import Foundation

@MainActor
public final class MockUserService: UserService {
    private var usersByID: [UUID: GlintUser]
    /// Contains accepted follow edges only. Pending requests are stored separately.
    private var followingByUserID: [UUID: Set<UUID>]
    private var blockedByUserID: [UUID: Set<UUID>]
    private var followRequests: [FollowRequest]
    private let profileStore: any MockUserProfileStore
    private let socialGraphStore: any MockSocialGraphStore
    private let subscriptionService: any SubscriptionService
    private let notificationSink: (any MockNotificationEventSink)?
    private var socialGraphLoadFailed = false

    public init(
        profileStore: (any MockUserProfileStore)? = nil,
        subscriptionService: (any SubscriptionService)? = nil,
        socialGraphStore: (any MockSocialGraphStore)? = nil,
        notificationSink: (any MockNotificationEventSink)? = nil
    ) {
        let profiles = profileStore ?? InMemoryMockUserProfileStore()
        let graphStore = socialGraphStore ?? InMemoryMockSocialGraphStore()
        self.profileStore = profiles
        self.socialGraphStore = graphStore
        self.subscriptionService = subscriptionService ?? MockSubscriptionService()
        self.notificationSink = notificationSink
        var users = Dictionary(uniqueKeysWithValues: MockData.users.map { ($0.id, $0) })
        for user in (try? profiles.loadProfiles()) ?? [] { users[user.id] = user }
        let graph: MockSocialGraphState?
        var graphLoadFailed = false
        do { graph = try graphStore.load() }
        catch {
            graph = nil
            graphLoadFailed = true
        }
        usersByID = users
        followingByUserID = graph?.followingByUserID ?? MockData.followingByUserID
        blockedByUserID = graph?.blockedByUserID ?? [:]
        followRequests = graph?.followRequests ?? MockData.followRequests
        socialGraphLoadFailed = graphLoadFailed
    }

    public func fetchUser(id: UUID, viewedBy viewerID: UUID) async throws -> GlintUser {
        guard var user = usersByID[id], !isBlockedEitherWay(id, viewerID) else {
            throw GlintServiceError.userNotFound
        }
        user.followerCount = followingByUserID.values.reduce(into: 0) { count, followed in
            if followed.contains(id) { count += 1 }
        }
        user.followingCount = followingByUserID[id, default: []].count
        return user
    }

    public func searchUsers(query: String, viewedBy viewerID: UUID, limit: Int) async throws -> [GlintUser] {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "@", with: "")
        guard !term.isEmpty else { return [] }
        let matches = usersByID.values.filter { user in
            !isBlockedEitherWay(user.id, viewerID)
                && (user.username.localizedCaseInsensitiveContains(term) || user.displayName.localizedCaseInsensitiveContains(term))
        }
        let counted = try await withVisibleUserCounts(matches)
        return Array(counted.sorted { $0.username < $1.username }.prefix(max(0, limit)))
    }

    public func isUsernameAvailable(_ username: String, excluding userID: UUID?) async throws -> Bool {
        let normalized = normalizeUsername(username)
        guard isValidUsername(normalized) else { return false }
        return !usersByID.values.contains { user in
            (userID == nil || user.id != userID) && user.username == normalized
        }
    }

    public func createOrUpdateProfile(userID: UUID, update: ProfileUpdate) async throws -> GlintUser {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        let normalizedUsername = normalizeUsername(update.username)
        guard isValidUsername(normalizedUsername) else { throw GlintServiceError.invalidUsername }
        guard try await isUsernameAvailable(normalizedUsername, excluding: userID) else {
            throw GlintServiceError.usernameUnavailable
        }
        guard !update.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GlintServiceError.emptyDisplayName
        }
        if update.avatarShape.requiresGlintPlus {
            guard try await subscriptionService.currentTier(for: userID) == .glintPlus else {
                throw GlintServiceError.glintPlusRequired
            }
        }

        var user = usersByID[userID] ?? GlintUser(username: normalizedUsername, displayName: update.displayName)
        user.username = normalizedUsername
        user.displayName = update.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.bio = update.bio
        user.avatarAssetName = update.avatarAssetName
        user.avatarFileURL = update.avatarFileURL
        user.bannerAssetName = update.bannerAssetName
        user.bannerFileURL = update.bannerFileURL
        user.bannerMediaKind = update.bannerMediaKind
        user.avatarShape = update.avatarShape
        user.isPrivate = update.isPrivate
        user.followerCount = followingByUserID.values.reduce(into: 0) { count, followed in
            if followed.contains(userID) { count += 1 }
        }
        user.followingCount = followingByUserID[userID, default: []].count
        try profileStore.saveProfile(user)
        usersByID[userID] = user
        return user
    }

    @discardableResult
    public func follow(userID: UUID, by currentUserID: UUID) async throws -> FollowRequestStatus {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard userID != currentUserID else { throw GlintServiceError.invalidInput("You cannot follow yourself.") }
        guard let target = usersByID[userID], usersByID[currentUserID] != nil else {
            throw GlintServiceError.userNotFound
        }
        guard !isBlockedEitherWay(userID, currentUserID) else { throw GlintServiceError.unavailable }
        if followingByUserID[currentUserID, default: []].contains(userID) { return .accepted }

        let status: FollowRequestStatus = try commitGraph {
            if let requestIndex = followRequests.indices.last(where: {
                followRequests[$0].requesterID == currentUserID && followRequests[$0].targetUserID == userID
            }) {
                let status = followRequests[requestIndex].status
                if status == .pending && target.isPrivate { return .pending }
                if target.isPrivate {
                    followRequests[requestIndex].status = .pending
                    followRequests[requestIndex].updatedAt = .now
                    return .pending
                }
                followRequests.removeAll { $0.requesterID == currentUserID && $0.targetUserID == userID }
            }

            if target.isPrivate {
                followRequests.append(FollowRequest(requesterID: currentUserID, targetUserID: userID))
                return .pending
            }
            addAcceptedFollow(from: currentUserID, to: userID)
            return .accepted
        }
        if status == .accepted {
            notificationSink?.recordNotification(
                recipientID: userID,
                event: .newFollower,
                actorID: currentUserID,
                destination: .profile(currentUserID)
            )
        }
        return status
    }

    public func unfollow(userID: UUID, by currentUserID: UUID) async throws {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        try commitGraph {
            removeFollow(from: currentUserID, to: userID)
            followRequests.removeAll {
                $0.requesterID == currentUserID && $0.targetUserID == userID
            }
        }
    }

    public func followStatus(userID: UUID, by currentUserID: UUID) async throws -> FollowRequestStatus? {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard !isBlockedEitherWay(userID, currentUserID) else { return nil }
        if followingByUserID[currentUserID, default: []].contains(userID) { return .accepted }
        return followRequests.last(where: {
            $0.requesterID == currentUserID && $0.targetUserID == userID && $0.status != .accepted
        })?.status
    }

    public func isFollowing(userID: UUID, by currentUserID: UUID) async throws -> Bool {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard !isBlockedEitherWay(userID, currentUserID) else { return false }
        return followingByUserID[currentUserID, default: []].contains(userID)
    }

    public func pendingFollowRequests(for userID: UUID) async throws -> [FollowRequest] {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        return followRequests
            .filter { $0.targetUserID == userID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func acceptFollowRequest(_ requestID: UUID, by userID: UUID) async throws {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard let index = followRequests.firstIndex(where: { $0.id == requestID }),
              followRequests[index].targetUserID == userID,
              followRequests[index].status == .pending else {
            throw GlintServiceError.invalidInput("This follow request is no longer pending.")
        }
        let requesterID = followRequests[index].requesterID
        guard usersByID[userID] != nil, usersByID[requesterID] != nil else { throw GlintServiceError.userNotFound }
        guard !isBlockedEitherWay(requesterID, userID) else { throw GlintServiceError.unavailable }
        try commitGraph {
            addAcceptedFollow(from: requesterID, to: userID)
            followRequests[index].status = .accepted
            followRequests[index].updatedAt = .now
        }
        notificationSink?.recordNotification(
            recipientID: userID,
            event: .newFollower,
            actorID: requesterID,
            destination: .profile(requesterID)
        )
    }

    public func rejectFollowRequest(_ requestID: UUID, by userID: UUID) async throws {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard let index = followRequests.firstIndex(where: { $0.id == requestID }),
              followRequests[index].targetUserID == userID,
              followRequests[index].status == .pending else {
            throw GlintServiceError.invalidInput("This follow request is no longer pending.")
        }
        try commitGraph {
            followRequests[index].status = .rejected
            followRequests[index].updatedAt = .now
        }
    }

    public func followers(of userID: UUID, viewedBy viewerID: UUID) async throws -> [GlintUser] {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard try await canViewContent(of: userID, by: viewerID) else { throw GlintServiceError.userNotFound }
        let ids = followingByUserID.compactMap { followerID, targets in targets.contains(userID) ? followerID : nil }
        var result: [GlintUser] = []
        for id in ids {
            guard try await canViewContent(of: id, by: viewerID) else { continue }
            if let user = try? await fetchUser(id: id, viewedBy: viewerID) { result.append(user) }
        }
        return result.sorted { $0.username < $1.username }
    }

    public func following(for userID: UUID, viewedBy viewerID: UUID) async throws -> [GlintUser] {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard try await canViewContent(of: userID, by: viewerID) else { throw GlintServiceError.userNotFound }
        var result: [GlintUser] = []
        for id in followingByUserID[userID, default: []] {
            guard try await canViewContent(of: id, by: viewerID) else { continue }
            if let user = try? await fetchUser(id: id, viewedBy: viewerID) { result.append(user) }
        }
        return result.sorted { $0.username < $1.username }
    }

    public func block(userID: UUID, by currentUserID: UUID) async throws {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard userID != currentUserID else { throw GlintServiceError.invalidInput("You cannot block your own account.") }
        guard usersByID[userID] != nil, usersByID[currentUserID] != nil else { throw GlintServiceError.userNotFound }
        try commitGraph {
            blockedByUserID[currentUserID, default: []].insert(userID)
            removeFollow(from: currentUserID, to: userID)
            removeFollow(from: userID, to: currentUserID)
            followRequests.removeAll {
                ($0.requesterID == currentUserID && $0.targetUserID == userID)
                    || ($0.requesterID == userID && $0.targetUserID == currentUserID)
            }
        }
    }

    public func unblock(userID: UUID, by currentUserID: UUID) async throws {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        try commitGraph { blockedByUserID[currentUserID, default: []].remove(userID) }
    }

    /// Only accounts explicitly blocked by this user are shown in Settings.
    public func blockedUsers(for currentUserID: UUID) async throws -> [GlintUser] {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        return blockedByUserID[currentUserID, default: []]
            .compactMap { usersByID[$0] }
            .sorted { $0.username < $1.username }
    }

    /// The effective hidden set is symmetric: accounts blocked by the viewer and accounts that blocked the viewer.
    public func blockedUserIDs(for viewerID: UUID) async throws -> Set<UUID> {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        var result = blockedByUserID[viewerID, default: []]
        for (blockerID, blockedIDs) in blockedByUserID where blockedIDs.contains(viewerID) {
            result.insert(blockerID)
        }
        return result
    }

    public func canViewContent(of ownerID: UUID, by viewerID: UUID) async throws -> Bool {
        guard !socialGraphLoadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        if ownerID == viewerID { return usersByID[ownerID] != nil }
        guard let owner = usersByID[ownerID], !isBlockedEitherWay(ownerID, viewerID) else { return false }
        return !owner.isPrivate || followingByUserID[viewerID, default: []].contains(ownerID)
    }

    private func isBlockedEitherWay(_ firstID: UUID, _ secondID: UUID) -> Bool {
        if socialGraphLoadFailed { return true }
        return blockedByUserID[firstID, default: []].contains(secondID)
            || blockedByUserID[secondID, default: []].contains(firstID)
    }

    private func addAcceptedFollow(from followerID: UUID, to followedID: UUID) {
        var following = followingByUserID[followerID, default: []]
        guard following.insert(followedID).inserted else { return }
        followingByUserID[followerID] = following
    }

    private func removeFollow(from followerID: UUID, to followedID: UUID) {
        var following = followingByUserID[followerID, default: []]
        guard following.remove(followedID) != nil else { return }
        followingByUserID[followerID] = following
    }

    private func commitGraph<T>(_ mutation: () -> T) throws -> T {
        let previous = MockSocialGraphState(
            followingByUserID: followingByUserID,
            blockedByUserID: blockedByUserID,
            followRequests: followRequests
        )
        let result = mutation()
        let updated = MockSocialGraphState(
            followingByUserID: followingByUserID,
            blockedByUserID: blockedByUserID,
            followRequests: followRequests
        )
        do {
            try socialGraphStore.save(updated)
            return result
        } catch {
            followingByUserID = previous.followingByUserID
            blockedByUserID = previous.blockedByUserID
            followRequests = previous.followRequests
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    private func withVisibleUserCounts(_ source: [GlintUser]) async throws -> [GlintUser] {
        var result: [GlintUser] = []
        for user in source {
            if let visible = try? await fetchUser(id: user.id, viewedBy: user.id) { result.append(visible) }
        }
        return result
    }

    private func normalizeUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "").lowercased()
    }

    private func isValidUsername(_ username: String) -> Bool {
        username.range(of: "^[a-z0-9._]{3,20}$", options: .regularExpression) != nil
    }
}
