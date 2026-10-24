import Foundation

@MainActor
public protocol SettingsService: AnyObject {
    func loadPreferences(for userID: UUID) async throws -> AppPreferences
    func savePreferences(_ preferences: AppPreferences, for userID: UUID) async throws
}
