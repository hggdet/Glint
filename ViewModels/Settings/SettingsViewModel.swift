import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed
    }

    private(set) var state: LoadState = .loading
    private(set) var preferences = AppPreferences()
    private(set) var user: GlintUser?
    private(set) var blockedUsers: [GlintUser] = []
    private(set) var isSavingPreferences = false
    private(set) var isUpdatingPrivacy = false
    private(set) var unblockingUserIDs: Set<UUID> = []
    private(set) var errorKey: String?
    private(set) var noticeKey: String?

    let viewerID: UUID
    private let services: GlintServices

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
    }

    func load() async {
        state = .loading
        errorKey = nil
        do {
            let loadedPreferences = try await services.settings.loadPreferences(for: viewerID)
            let loadedUser = try await services.users.fetchUser(id: viewerID, viewedBy: viewerID)
            let loadedBlocked = try await services.users.blockedUsers(for: viewerID)
            preferences = loadedPreferences
            user = loadedUser
            blockedUsers = await normalizedBlockedUsers(loadedBlocked)
            state = .ready
        } catch {
            state = .failed
            errorKey = "settings.error.load"
        }
    }

    func retry() async { await load() }

    func setLanguage(_ language: GlintLanguage) async -> Bool {
        var updated = preferences
        updated.language = language
        return await savePreferences(updated)
    }

    func setAppearance(_ appearance: GlintAppearance) async -> Bool {
        var updated = preferences
        updated.appearance = appearance
        return await savePreferences(updated)
    }

    func setNotificationPreference(_ kind: NotificationPreferenceKind, isEnabled: Bool) async {
        var updated = preferences
        switch kind {
        case .likes: updated.notificationPreferences.likes = isEnabled
        case .comments: updated.notificationPreferences.comments = isEnabled
        case .newFollowers: updated.notificationPreferences.newFollowers = isEnabled
        }
        _ = await savePreferences(updated)
    }

    func setPrivateAccount(_ isPrivate: Bool) async {
        guard !isUpdatingPrivacy, let user else { return }
        isUpdatingPrivacy = true
        errorKey = nil
        defer { isUpdatingPrivacy = false }
        do {
            let tier = try await services.subscriptions.currentTier(for: viewerID)
            let update = ProfileUpdate(
                username: user.username,
                displayName: user.displayName,
                bio: user.bio,
                avatarAssetName: user.avatarAssetName,
                avatarFileURL: user.avatarFileURL,
                bannerAssetName: user.bannerAssetName,
                bannerFileURL: user.bannerFileURL,
                bannerMediaKind: user.bannerMediaKind,
                avatarShape: tier == .glintPlus ? user.avatarShape : .circle,
                isPrivate: isPrivate
            )
            self.user = try await services.users.createOrUpdateProfile(userID: viewerID, update: update)
            noticeKey = "settings.saved"
        } catch {
            errorKey = errorKey(for: error)
        }
    }

    func unblock(_ blockedUser: GlintUser) async {
        guard !unblockingUserIDs.contains(blockedUser.id) else { return }
        unblockingUserIDs.insert(blockedUser.id)
        errorKey = nil
        defer { unblockingUserIDs.remove(blockedUser.id) }
        do {
            try await services.users.unblock(userID: blockedUser.id, by: viewerID)
            blockedUsers.removeAll { $0.id == blockedUser.id }
            noticeKey = "settings.blocked.unblocked"
        } catch {
            errorKey = errorKey(for: error)
        }
    }

    func refreshBlockedUsers() async {
        do {
            let users = try await services.users.blockedUsers(for: viewerID)
            blockedUsers = await normalizedBlockedUsers(users)
        }
        catch { errorKey = errorKey(for: error) }
    }

    private func normalizedBlockedUsers(_ users: [GlintUser]) async -> [GlintUser] {
        guard services.subscriptions is MockSubscriptionService else { return users }
        var result = users
        for index in result.indices {
            if (try? await services.subscriptions.currentTier(for: result[index].id)) != .glintPlus {
                result[index].avatarShape = .circle
            }
        }
        return result
    }

    private func savePreferences(_ updated: AppPreferences) async -> Bool {
        guard !isSavingPreferences else { return false }
        let previous = preferences
        isSavingPreferences = true
        errorKey = nil
        noticeKey = nil
        defer { isSavingPreferences = false }
        preferences = updated
        do {
            try await services.settings.savePreferences(updated, for: viewerID)
            noticeKey = "settings.saved"
            return true
        } catch {
            preferences = previous
            errorKey = errorKey(for: error)
            return false
        }
    }

    private func errorKey(for error: Error) -> String {
        guard let serviceError = error as? GlintServiceError else { return "settings.error.generic" }
        switch serviceError {
        case .localDataPersistenceFailed: return "settings.error.save"
        case .userNotFound: return "settings.error.accountUnavailable"
        default: return "settings.error.generic"
        }
    }
}

enum NotificationPreferenceKind: Equatable, Sendable {
    case likes
    case comments
    case newFollowers
}
