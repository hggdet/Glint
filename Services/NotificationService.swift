import Foundation

@MainActor
public protocol NotificationService: AnyObject, Sendable {
    func fetchNotifications(for recipientID: UUID, page: Int, pageSize: Int) async throws -> PageResult<GlintNotification>
    func unreadCount(for recipientID: UUID) async throws -> Int
    func markAsRead(_ notificationID: UUID, for recipientID: UUID) async throws
    func markAllAsRead(for recipientID: UUID) async throws
}
