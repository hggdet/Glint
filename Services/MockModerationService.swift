import Foundation

@MainActor
public final class MockModerationService: ModerationService {
    public private(set) var submittedReports: [ModerationReport] = []
    private let simulatedDecision: ModerationDecision

    public init(simulatedDecision: ModerationDecision = .allow) {
        self.simulatedDecision = simulatedDecision
    }

    public func checkBeforePublishing(_ content: ModerationContent, submittedBy userID: UUID) async throws -> ModerationDecision {
        switch content {
        case .post(let caption, let media):
            guard !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !media.isEmpty else {
                return .reject(reason: .emptyContent)
            }
        case .reel(let caption, let media):
            guard media.contains(where: { $0.kind == .video }) else {
                return .reject(reason: .mediaRequired)
            }
            guard !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !media.isEmpty else {
                return .reject(reason: .emptyContent)
            }
        case .comment(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .reject(reason: .emptyContent)
            }
        case .story(media: _):
            break
        }
        return simulatedDecision
    }

    public func submitReport(_ report: ModerationReport) async throws {
        submittedReports.append(report)
    }
}
