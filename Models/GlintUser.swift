import Foundation

public enum GlintSubscriptionTier: String, Codable, Equatable, Hashable, Sendable {
    case free
    case glintPlus
}

public struct GlintUser: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var username: String
    public var displayName: String
    public var bio: String
    public var avatarAssetName: String?
    public var avatarFileURL: URL?
    public var bannerAssetName: String?
    public var bannerFileURL: URL?
    public var bannerMediaKind: PostMediaKind?
    public var followerCount: Int
    public var followingCount: Int
    public var postCount: Int
    public var isPrivate: Bool
    public var isVerified: Bool
    public var avatarShape: AvatarShape
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        username: String,
        displayName: String,
        bio: String = "",
        avatarAssetName: String? = nil,
        avatarFileURL: URL? = nil,
        bannerAssetName: String? = nil,
        bannerFileURL: URL? = nil,
        bannerMediaKind: PostMediaKind? = nil,
        followerCount: Int = 0,
        followingCount: Int = 0,
        postCount: Int = 0,
        isPrivate: Bool = false,
        isVerified: Bool = false,
        avatarShape: AvatarShape = .circle,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarAssetName = avatarAssetName
        self.avatarFileURL = avatarFileURL
        self.bannerAssetName = bannerAssetName
        self.bannerFileURL = bannerFileURL
        self.bannerMediaKind = bannerMediaKind
        self.followerCount = max(0, followerCount)
        self.followingCount = max(0, followingCount)
        self.postCount = max(0, postCount)
        self.isPrivate = isPrivate
        self.isVerified = isVerified
        self.avatarShape = avatarShape
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, username, displayName, bio, avatarAssetName, avatarFileURL
        case bannerAssetName, bannerFileURL, bannerMediaKind
        case followerCount, followingCount, postCount, isPrivate, isVerified, avatarShape, createdAt
    }

    /// Missing fields from older local mock profiles get safe defaults so migrations preserve accounts.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        avatarAssetName = try container.decodeIfPresent(String.self, forKey: .avatarAssetName)
        avatarFileURL = try container.decodeIfPresent(URL.self, forKey: .avatarFileURL)
        bannerAssetName = try container.decodeIfPresent(String.self, forKey: .bannerAssetName)
        bannerFileURL = try container.decodeIfPresent(URL.self, forKey: .bannerFileURL)
        bannerMediaKind = try container.decodeIfPresent(PostMediaKind.self, forKey: .bannerMediaKind)
        followerCount = max(0, try container.decodeIfPresent(Int.self, forKey: .followerCount) ?? 0)
        followingCount = max(0, try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0)
        postCount = max(0, try container.decodeIfPresent(Int.self, forKey: .postCount) ?? 0)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        avatarShape = try container.decodeIfPresent(AvatarShape.self, forKey: .avatarShape) ?? .circle
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}
