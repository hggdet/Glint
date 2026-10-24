import Foundation

public enum PostMediaKind: String, Codable, Equatable, Hashable, Sendable {
    case photo
    case video
}

/// Media is asset-first for offline mock data; remoteURL is reserved for a future backend/CDN.
public struct PostMedia: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: PostMediaKind
    public var assetName: String?
    public var localFileURL: URL?
    public var remoteURL: URL?
    public var accessibilityDescription: String
    public var aspectRatio: Double
    public var durationSeconds: Double?

    public init(
        id: UUID = UUID(),
        kind: PostMediaKind,
        assetName: String? = nil,
        localFileURL: URL? = nil,
        remoteURL: URL? = nil,
        accessibilityDescription: String = "",
        aspectRatio: Double = 1,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.assetName = assetName
        self.localFileURL = localFileURL
        self.remoteURL = remoteURL
        self.accessibilityDescription = accessibilityDescription
        self.aspectRatio = max(0.1, aspectRatio)
        self.durationSeconds = durationSeconds
    }
}
