import Foundation

@MainActor
public protocol ModerationService: AnyObject {
    /// Checks user-generated content before publication. Production services must enforce this server-side.
    func checkBeforePublishing(_ content: ModerationContent, submittedBy userID: UUID) async throws -> ModerationDecision
    func submitReport(_ report: ModerationReport) async throws
}
