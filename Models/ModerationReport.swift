import Foundation

public enum ModerationTarget: Codable, Equatable, Sendable {
    case post(UUID)
    case reel(UUID)
    case story(UUID)
    case comment(UUID)
    case user(UUID)
}

public enum ModerationReason: String, Codable, CaseIterable, Hashable, Sendable {
    case spam
    case abuse
    case nudity
    case violence
    case other
}

public struct ModerationReport: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var reporterID: UUID
    public var target: ModerationTarget
    public var reason: ModerationReason
    public var note: String?
    public var submittedAt: Date

    public init(
        id: UUID = UUID(),
        reporterID: UUID,
        target: ModerationTarget,
        reason: ModerationReason,
        note: String? = nil,
        submittedAt: Date = .now
    ) {
        self.id = id
        self.reporterID = reporterID
        self.target = target
        self.reason = reason
        self.note = note
        self.submittedAt = submittedAt
    }
}
