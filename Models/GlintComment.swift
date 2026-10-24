import Foundation

public struct GlintComment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var postID: UUID
    public var authorID: UUID
    public var text: String
    public var createdAt: Date
    public var likeCount: Int
    public var parentCommentID: UUID?

    public init(
        id: UUID = UUID(),
        postID: UUID,
        authorID: UUID,
        text: String,
        createdAt: Date = .now,
        likeCount: Int = 0,
        parentCommentID: UUID? = nil
    ) {
        self.id = id
        self.postID = postID
        self.authorID = authorID
        self.text = text
        self.createdAt = createdAt
        self.likeCount = max(0, likeCount)
        self.parentCommentID = parentCommentID
    }
}
