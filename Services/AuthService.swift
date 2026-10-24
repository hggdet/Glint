import Foundation

@MainActor
public protocol AuthService: AnyObject {
    var currentSession: AuthSession? { get }

    func restoreSession() async throws -> AuthSession?
    func signUp(email: String, password: String, consent: LegalConsent) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws
    func refreshSession(_ session: AuthSession) async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
}
