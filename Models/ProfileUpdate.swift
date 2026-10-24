import Foundation

public struct ProfileUpdate: Equatable, Sendable {
    public var username: String
    public var displayName: String
    public var bio: String
    public var avatarAssetName: String?
    public var avatarFileURL: URL?
    public var bannerAssetName: String?
    public var bannerFileURL: URL?
    public var bannerMediaKind: PostMediaKind?
    public var avatarShape: AvatarShape
    public var isPrivate: Bool

    public init(
        username: String,
        displayName: String,
        bio: String = "",
        avatarAssetName: String? = nil,
        avatarFileURL: URL? = nil,
        bannerAssetName: String? = nil,
        bannerFileURL: URL? = nil,
        bannerMediaKind: PostMediaKind? = nil,
        avatarShape: AvatarShape = .circle,
        isPrivate: Bool = false
    ) {
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarAssetName = avatarAssetName
        self.avatarFileURL = avatarFileURL
        self.bannerAssetName = bannerAssetName
        self.bannerFileURL = bannerFileURL
        self.bannerMediaKind = bannerMediaKind
        self.avatarShape = avatarShape
        self.isPrivate = isPrivate
    }
}
