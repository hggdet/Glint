import Foundation

public enum LegalPolicyVersions {
    public static let terms = "1.0"
    public static let privacy = "1.0"
}

public struct LegalConsent: Codable, Equatable, Sendable {
    public let termsVersion: String
    public let privacyVersion: String
    public let acceptedAt: Date

    public init(termsVersion: String, privacyVersion: String, acceptedAt: Date = .now) {
        self.termsVersion = termsVersion
        self.privacyVersion = privacyVersion
        self.acceptedAt = acceptedAt
    }

    public var isComplete: Bool {
        !termsVersion.isEmpty && !privacyVersion.isEmpty
    }
}
