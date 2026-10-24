import Foundation
import Observation

public enum AuthRoute: Equatable {
    case loading
    case welcome
    case signIn
    case signUp
    case passwordReset
    case profileSetup
    case authenticated
}

public enum UsernameAvailability: Equatable {
    case idle
    case checking
    case available
    case taken
    case invalid
}

@MainActor
@Observable
public final class AuthViewModel {
    public private(set) var route: AuthRoute = .loading
    public private(set) var currentSession: AuthSession?
    public private(set) var currentUser: GlintUser?
    public private(set) var isWorking = false
    public private(set) var errorMessageKey: String?
    public private(set) var noticeMessageKey: String?
    public private(set) var resetRequestSent = false
    public private(set) var usernameAvailability: UsernameAvailability = .idle

    public var email = ""
    public var password = ""
    public var confirmPassword = ""
    public var acceptedTerms = false
    public var profileUsername = ""
    public var profileDisplayName = ""
    public var profileAvatarAssetName: String? = "avatar_noura"

    private let services: GlintServices
    private var usernameCheckTask: Task<Void, Never>?

    public init(services: GlintServices) {
        self.services = services
    }

    public func restoreSession() async {
        clearMessages()
        route = .loading
        do {
            guard let session = try await services.auth.restoreSession() else {
                route = .welcome
                return
            }
            currentSession = session
            await resolveProfile(for: session)
        } catch {
            route = .welcome
            errorMessageKey = messageKey(for: error)
        }
    }

    public func showWelcome() {
        clearMessages()
        route = .welcome
    }

    public func showSignIn() {
        clearMessages()
        route = .signIn
    }

    public func showSignUp() {
        clearMessages()
        route = .signUp
    }

    public func showPasswordReset() {
        clearMessages()
        resetRequestSent = false
        route = .passwordReset
    }

    public func signIn() async {
        clearMessages()
        guard validateEmail() else { return }
        guard !password.isEmpty else {
            errorMessageKey = "auth.error.passwordRequired"
            return
        }
        await perform { [self] in
            let session = try await services.auth.signIn(email: email, password: password)
            currentSession = session
            await resolveProfile(for: session)
        }
    }

    public func signUp() async {
        clearMessages()
        guard validateEmail() else { return }
        guard password.count >= 8 else {
            errorMessageKey = "auth.error.passwordTooShort"
            return
        }
        guard password == confirmPassword else {
            errorMessageKey = "auth.error.passwordMismatch"
            return
        }
        guard acceptedTerms else {
            errorMessageKey = "auth.error.legalConsentRequired"
            return
        }

        await perform { [self] in
            let consent = LegalConsent(termsVersion: LegalPolicyVersions.terms, privacyVersion: LegalPolicyVersions.privacy)
            let session = try await services.auth.signUp(email: email, password: password, consent: consent)
            currentSession = session
            let localPart = email.split(separator: "@").first.map(String.init) ?? ""
            profileDisplayName = localPart
            profileUsername = String(localPart.lowercased().replacingOccurrences(of: #"[^a-z0-9._]"#, with: "", options: .regularExpression).prefix(20))
            updateProfileUsername(profileUsername)
            route = .profileSetup
        }
    }

    public func requestPasswordReset() async {
        clearMessages()
        guard validateEmail() else { return }
        await perform { [self] in
            try await services.auth.requestPasswordReset(email: email)
            resetRequestSent = true
            noticeMessageKey = "auth.reset.mockNotice"
        }
    }

    public func updateProfileUsername(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        profileUsername = normalized
        usernameCheckTask?.cancel()

        guard normalized.range(of: #"^[a-z0-9._]{3,20}$"#, options: .regularExpression) != nil else {
            usernameAvailability = normalized.isEmpty ? .idle : .invalid
            return
        }
        guard let userID = currentSession?.userID else {
            usernameAvailability = .idle
            return
        }

        usernameAvailability = .checking
        usernameCheckTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                let available = try await self.services.users.isUsernameAvailable(normalized, excluding: userID)
                guard !Task.isCancelled else { return }
                self.usernameAvailability = available ? .available : .taken
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.usernameAvailability = .idle
            }
        }
    }

    public func completeProfile() async {
        clearMessages()
        guard let session = currentSession else {
            errorMessageKey = "auth.error.sessionMissing"
            route = .welcome
            return
        }
        guard profileUsername.range(of: #"^[a-z0-9._]{3,20}$"#, options: .regularExpression) != nil else {
            usernameAvailability = .invalid
            errorMessageKey = "auth.error.usernameInvalid"
            return
        }
        guard !profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessageKey = "auth.error.displayNameRequired"
            return
        }

        await perform { [self] in
            let available = try await services.users.isUsernameAvailable(profileUsername, excluding: session.userID)
            guard available else { throw GlintServiceError.usernameUnavailable }
            let update = ProfileUpdate(
                username: profileUsername,
                displayName: profileDisplayName,
                avatarAssetName: profileAvatarAssetName
            )
            currentUser = try await services.users.createOrUpdateProfile(userID: session.userID, update: update)
            route = .authenticated
        }
    }

    public func signOut() async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        clearMessages()
        do {
            try await services.auth.signOut()
            currentSession = nil
            currentUser = nil
            password = ""
            confirmPassword = ""
            route = .welcome
            return true
        } catch {
            errorMessageKey = messageKey(for: error)
            return false
        }
    }

    public func deleteAccount() async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        clearMessages()
        do {
            try await services.auth.deleteAccount()
            currentSession = nil
            currentUser = nil
            password = ""
            confirmPassword = ""
            route = .welcome
            return true
        } catch {
            errorMessageKey = messageKey(for: error)
            return false
        }
    }

    private func resolveProfile(for session: AuthSession) async {
        do {
            currentUser = try await services.users.fetchUser(id: session.userID, viewedBy: session.userID)
            route = .authenticated
        } catch GlintServiceError.userNotFound {
            route = .profileSetup
        } catch {
            errorMessageKey = messageKey(for: error)
            route = .welcome
        }
    }

    private func validateEmail() -> Bool {
        let candidate = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard candidate.range(of: pattern, options: .regularExpression) != nil else {
            errorMessageKey = "auth.error.emailInvalid"
            return false
        }
        email = candidate
        return true
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessageKey = messageKey(for: error)
        }
    }

    private func messageKey(for error: Error) -> String {
        guard let serviceError = error as? GlintServiceError else {
            return "auth.error.generic"
        }
        switch serviceError {
        case .invalidCredentials: return "auth.error.credentials"
        case .accountAlreadyExists: return "auth.error.accountExists"
        case .usernameUnavailable: return "auth.error.usernameTaken"
        case .sessionExpired: return "auth.error.sessionExpired"
        case .sessionAlreadyExists: return "auth.error.sessionAlreadyExists"
        case .sessionPersistenceFailed: return "auth.error.sessionSave"
        case .registrationRollbackFailed: return "auth.error.registrationRollback"
        case .legalConsentRequired: return "auth.error.legalConsentRequired"
        case .invalidInput(_): return "auth.error.generic"
        default: return "auth.error.generic"
        }
    }

    private func clearMessages() {
        errorMessageKey = nil
        noticeMessageKey = nil
    }
}
