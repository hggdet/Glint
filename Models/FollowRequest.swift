import Foundation

public enum FollowRequestStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case pending
    case accepted
    case rejected
}

public struct FollowRequest: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var requesterID: UUID
    public var targetUserID: UUID
    public var status: FollowRequestStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        requesterID: UUID,
        targetUserID: UUID,
        status: FollowRequestStatus = .pending,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.requesterID = requesterID
        self.targetUserID = targetUserID
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
