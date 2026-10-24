import Foundation

public enum GlintServiceError: Error, LocalizedError, Equatable {
    case invalidInput(String)
    case invalidCredentials
    case accountAlreadyExists
    case userNotFound
    case postNotFound
    case usernameUnavailable
    case sessionExpired
    case emptyComment
    case unavailable
    case moderationRejected(ModerationDecisionReason)
    case moderationRequiresReview(ModerationDecisionReason)
    case legalConsentRequired
    case sessionPersistenceFailed
    case localDataPersistenceFailed
    case registrationRollbackFailed
    case sessionAlreadyExists
    case glintPlusRequired
    case subscriptionProductUnavailable
    case subscriptionCancelled
    case subscriptionPending
    case subscriptionVerificationFailed
    case invalidUsername
    case emptyDisplayName

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return message
        case .invalidCredentials: return "The email or password is incorrect."
        case .accountAlreadyExists: return "An account with this email already exists."
        case .userNotFound: return "This profile could not be found."
        case .postNotFound: return "This post could not be found."
        case .usernameUnavailable: return "That username is already taken."
        case .sessionExpired: return "Your session has expired. Please log in again."
        case .emptyComment: return "Write a comment before sending."
        case .unavailable: return "This service is temporarily unavailable. Please try again."
        case .moderationRejected(let reason): return "This content cannot be published (\(reason.rawValue))."
        case .moderationRequiresReview(let reason): return "This content needs review before it can be published (\(reason.rawValue))."
        case .legalConsentRequired: return "Accept the Terms of Use and Privacy Policy to create an account."
        case .sessionPersistenceFailed: return "Your secure session could not be saved. Please try again."
        case .localDataPersistenceFailed: return "Local demo data could not be saved. Please try again."
        case .registrationRollbackFailed: return "Account setup could not be completed or safely rolled back. Do not retry with real credentials."
        case .sessionAlreadyExists: return "Log out before creating another account."
        case .glintPlusRequired: return "This profile shape requires Glint+."
        case .subscriptionProductUnavailable: return "Glint+ plans are unavailable right now. Please try again later."
        case .subscriptionCancelled: return "The purchase was cancelled."
        case .subscriptionPending: return "The purchase is waiting for approval."
        case .subscriptionVerificationFailed: return "The App Store could not verify this subscription."
        case .invalidUsername: return "Use 3–20 lowercase letters, numbers, dots, or underscores for your username."
        case .emptyDisplayName: return "Your display name cannot be empty."
        }
    }
}
