import Foundation

@MainActor
public final class MockAuthService: AuthService {
    public static let demoEmail = "demo@glint.app"
    public static let demoPassword = "glint-demo"
    public private(set) var currentSession: AuthSession?
    public private(set) var acceptedConsentsByUserID: [UUID: LegalConsent] = [:]
    private let sessionStore: any AuthSessionStore
    private let consentStore: any LegalConsentStore
    private let credentialStore: any MockCredentialStore
    private var credentialsByEmail: [String: MockAccountCredential]

    public init(
        sessionStore: (any AuthSessionStore)? = nil,
        consentStore: (any LegalConsentStore)? = nil,
        credentialStore: (any MockCredentialStore)? = nil
    ) {
        self.sessionStore = sessionStore ?? InMemoryAuthSessionStore()
        let store = consentStore ?? InMemoryLegalConsentStore()
        self.consentStore = store
        acceptedConsentsByUserID = (try? store.loadAll()) ?? [:]
        let credentials = credentialStore ?? InMemoryMockCredentialStore()
        self.credentialStore = credentials
        credentialsByEmail = (try? credentials.loadAll()) ?? [:]
    }

    public func restoreSession() async throws -> AuthSession? {
        guard let session = try sessionStore.load() else {
            currentSession = nil
            return nil
        }
        guard session.isExpired else {
            currentSession = session
            return session
        }
        do {
            return try await refreshSession(session)
        } catch {
            try sessionStore.delete()
            currentSession = nil
            throw GlintServiceError.sessionExpired
        }
    }

    public func signUp(email: String, password: String, consent: LegalConsent) async throws -> AuthSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(normalizedEmail) else {
            throw GlintServiceError.invalidInput("Enter a valid email address.")
        }
        guard normalizedEmail != Self.demoEmail else { throw GlintServiceError.accountAlreadyExists }
        guard password.count >= 8 else {
            throw GlintServiceError.invalidInput("Password must be at least 8 characters.")
        }
        guard consent.isComplete else { throw GlintServiceError.legalConsentRequired }
        guard credentialsByEmail[normalizedEmail] == nil else { throw GlintServiceError.accountAlreadyExists }
        if let existingSession = try sessionStore.load() {
            guard existingSession.isExpired else { throw GlintServiceError.sessionAlreadyExists }
            try sessionStore.delete()
        }

        let session = makeSession(userID: UUID())
        let credential = MockAccountCredential.make(userID: session.userID, password: password)
        var attemptedSessionSave = false
        do {
            try consentStore.save(consent, for: session.userID)
            try credentialStore.save(credential, for: normalizedEmail)
            attemptedSessionSave = true
            try sessionStore.save(session)
        } catch {
            var rollbackFailed = false
            if attemptedSessionSave {
                do { try sessionStore.delete() } catch { rollbackFailed = true }
            }
            do { try credentialStore.delete(for: normalizedEmail) } catch { rollbackFailed = true }
            do { try consentStore.delete(for: session.userID) } catch { rollbackFailed = true }
            if rollbackFailed { throw GlintServiceError.registrationRollbackFailed }
            throw error
        }
        credentialsByEmail[normalizedEmail] = credential
        currentSession = session
        acceptedConsentsByUserID[session.userID] = consent
        return session
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(normalizedEmail) else {
            throw GlintServiceError.invalidCredentials
        }
        let userID: UUID
        if normalizedEmail == Self.demoEmail {
            guard password == Self.demoPassword else { throw GlintServiceError.invalidCredentials }
            userID = MockData.currentUser.id
        } else if let credential = credentialsByEmail[normalizedEmail], credential.matches(password: password) {
            userID = credential.userID
        } else {
            throw GlintServiceError.invalidCredentials
        }
        let session = makeSession(userID: userID)
        try sessionStore.save(session)
        currentSession = session
        return session
    }

    public func requestPasswordReset(email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(normalizedEmail) else {
            throw GlintServiceError.invalidInput("Enter a valid email address.")
        }
        // Mock only: no email is sent.
    }

    public func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        guard !session.refreshToken.isEmpty else { throw GlintServiceError.sessionExpired }
        let refreshed = makeSession(userID: session.userID)
        try sessionStore.save(refreshed)
        currentSession = refreshed
        return refreshed
    }

    public func signOut() async throws {
        try sessionStore.delete()
        currentSession = nil
    }

    public func deleteAccount() async throws {
        // Mock only: production deletion must remove or anonymize all account-owned server data.
        try await signOut()
    }

    private func makeSession(userID: UUID) -> AuthSession {
        AuthSession(
            userID: userID,
            accessToken: "mock-access-\(UUID().uuidString)",
            refreshToken: "mock-refresh-\(UUID().uuidString)",
            expiresAt: .now.addingTimeInterval(3_600)
        )
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.range(of: #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}
