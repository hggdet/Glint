import Foundation

@MainActor
public final class MockSettingsService: SettingsService {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadPreferences(for userID: UUID) async throws -> AppPreferences {
        guard let data = defaults.data(forKey: key(for: userID)) else { return AppPreferences() }
        do { return try JSONDecoder().decode(AppPreferences.self, from: data) }
        catch { throw GlintServiceError.localDataPersistenceFailed }
    }

    public func savePreferences(_ preferences: AppPreferences, for userID: UUID) async throws {
        do { defaults.set(try JSONEncoder().encode(preferences), forKey: key(for: userID)) }
        catch { throw GlintServiceError.localDataPersistenceFailed }
    }

    private func key(for userID: UUID) -> String {
        "glint.mock.preferences.v1.\(userID.uuidString.lowercased())"
    }
}
