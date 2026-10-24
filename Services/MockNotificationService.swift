import Foundation

@MainActor
public final class MockNotificationService: NotificationService {
    private let userService: any UserService
    private let postService: any PostService
    private let settingsService: any SettingsService
    private let store: MockNotificationStore

    public init(
        userService: any UserService,
        postService: any PostService,
        settingsService: any SettingsService,
        store: MockNotificationStore
    ) {
        self.userService = userService
        self.postService = postService
        self.settingsService = settingsService
        self.store = store
    }

    public func fetchNotifications(for recipientID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintNotification> {
        let recipientNotifications = try await visibleNotifications(for: recipientID)
        let visible = recipientNotifications.sorted { $0.createdAt > $1.createdAt }
        let safePage = max(0, page)
        let safeSize = max(1, pageSize)
        let start = min(safePage * safeSize, visible.count)
        let end = min(start + safeSize, visible.count)
        return PageResult(items: Array(visible[start..<end]), nextPage: end < visible.count ? safePage + 1 : nil)
    }

    public func unreadCount(for recipientID: UUID) async throws -> Int {
        let notifications = try await visibleNotifications(for: recipientID)
        return notifications.filter { !$0.isRead }.count
    }

    public func markAsRead(_ notificationID: UUID, for recipientID: UUID) async throws {
        try store.markAsRead(notificationID, for: recipientID)
    }

    public func markAllAsRead(for recipientID: UUID) async throws {
        try store.markAllAsRead(for: recipientID)
    }

    private func visibleNotifications(for recipientID: UUID) async throws -> [GlintNotification] {
        let hiddenIDs = try await userService.blockedUserIDs(for: recipientID)
        let appPreferences = try await settingsService.loadPreferences(for: recipientID)
        let preferences = appPreferences.notificationPreferences
        let notifications = try store.notifications(for: recipientID)
        var result: [GlintNotification] = []
        for notification in notifications {
            let isEnabled: Bool
            switch notification.event {
            case .like: isEnabled = preferences.likes
            case .comment(_): isEnabled = preferences.comments
            case .newFollower: isEnabled = preferences.newFollowers
            }
            guard isEnabled else { continue }
            guard !hiddenIDs.contains(notification.actorID),
                  (try? await userService.fetchUser(id: notification.actorID, viewedBy: recipientID)) != nil else { continue }
            if case .comment = notification.event {
                guard try await userService.canViewContent(of: notification.actorID, by: recipientID) else { continue }
            }
            switch notification.destination {
            case .post(let postID):
                guard try await postService.canViewPost(postID, for: recipientID) else { continue }
            case .profile(let targetUserID):
                guard !hiddenIDs.contains(targetUserID),
                      (try? await userService.fetchUser(id: targetUserID, viewedBy: recipientID)) != nil else { continue }
            }
            result.append(notification)
        }
        return result
    }
}
