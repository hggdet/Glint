import Foundation

@MainActor
public protocol UserService: AnyObject, Sendable {
    func fetchUser(id: UUID, viewedBy viewerID: UUID) async throws -> GlintUser
    func searchUsers(query: String, viewedBy viewerID: UUID, limit: Int) async throws -> [GlintUser]
    func isUsernameAvailable(_ username: String, excluding userID: UUID?) async throws -> Bool
    func createOrUpdateProfile(userID: UUID, update: ProfileUpdate) async throws -> GlintUser

    /// Public profiles become accepted follows immediately; private profiles create pending requests.
    func follow(userID: UUID, by currentUserID: UUID) async throws -> FollowRequestStatus
    func unfollow(userID: UUID, by currentUserID: UUID) async throws
    func followStatus(userID: UUID, by currentUserID: UUID) async throws -> FollowRequestStatus?
    func isFollowing(userID: UUID, by currentUserID: UUID) async throws -> Bool
    func pendingFollowRequests(for userID: UUID) async throws -> [FollowRequest]
    func acceptFollowRequest(_ requestID: UUID, by userID: UUID) async throws
    func rejectFollowRequest(_ requestID: UUID, by userID: UUID) async throws

    func followers(of userID: UUID, viewedBy viewerID: UUID) async throws -> [GlintUser]
    func following(for userID: UUID, viewedBy viewerID: UUID) async throws -> [GlintUser]
    func block(userID: UUID, by currentUserID: UUID) async throws
    func unblock(userID: UUID, by currentUserID: UUID) async throws
    func blockedUsers(for currentUserID: UUID) async throws -> [GlintUser]

    /// Includes users hidden by either direction of a block; this is the shared source for content services.
    func blockedUserIDs(for viewerID: UUID) async throws -> Set<UUID>
    /// True for the owner, accepted followers of private accounts, or viewers of public accounts, unless blocked.
    func canViewContent(of ownerID: UUID, by viewerID: UUID) async throws -> Bool
}
