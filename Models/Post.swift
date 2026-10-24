import Foundation

public enum GlintPostKind: String, Codable, Equatable, Sendable {
    case post
    case reel
}

public struct GlintPost: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var authorID: UUID
    public var caption: String
    public var media: [PostMedia]
    public var contentKind: GlintPostKind
    public var createdAt: Date
    public var likeCount: Int
    public var commentCount: Int
    public var shareCount: Int
    public var isLiked: Bool
    public var isSaved: Bool

    public init(
        id: UUID = UUID(),
        authorID: UUID,
        caption: String = "",
        media: [PostMedia] = [],
        contentKind: GlintPostKind = .post,
        createdAt: Date = .now,
        likeCount: Int = 0,
        commentCount: Int = 0,
        shareCount: Int = 0,
        isLiked: Bool = false,
        isSaved: Bool = false
    ) {
        self.id = id
        self.authorID = authorID
        self.caption = caption
        self.media = media
        self.contentKind = contentKind
        self.createdAt = createdAt
        self.likeCount = max(0, likeCount)
        self.commentCount = max(0, commentCount)
        self.shareCount = max(0, shareCount)
        self.isLiked = isLiked
        self.isSaved = isSaved
    }

    private enum CodingKeys: String, CodingKey {
        case id, authorID, caption, media, contentKind, createdAt
        case likeCount, commentCount, shareCount, isLiked, isSaved
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorID = try container.decode(UUID.self, forKey: .authorID)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        media = try container.decodeIfPresent([PostMedia].self, forKey: .media) ?? []
        contentKind = try container.decodeIfPresent(GlintPostKind.self, forKey: .contentKind) ?? .post
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        likeCount = max(0, try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0)
        commentCount = max(0, try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0)
        shareCount = max(0, try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0)
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
    }

    public var isTextOnly: Bool { media.isEmpty }
    public var containsVideo: Bool { media.contains { $0.kind == .video } }
}
