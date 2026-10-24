import Foundation

/// Content submitted to the moderation boundary before it becomes public.
public enum ModerationContent: Codable, Equatable, Sendable {
    case post(caption: String, media: [PostMedia])
    case reel(caption: String, media: [PostMedia])
    case comment(text: String)
    case story(media: PostMedia)
}

public enum ModerationDecision: Codable, Equatable, Sendable {
    case allow
    case reject(reason: ModerationDecisionReason)
    case review(reason: ModerationDecisionReason)
}

public enum ModerationDecisionReason: String, Codable, Equatable, Sendable {
    case emptyContent
    case mediaRequired
    case manualReview
    case policyCheckRequired
}
