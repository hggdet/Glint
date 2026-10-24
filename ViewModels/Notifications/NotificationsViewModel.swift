import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case empty
        case failed
    }

    private(set) var state: LoadState = .loading
    private(set) var notifications: [GlintNotification] = []
    private(set) var actorsByID: [UUID: GlintUser] = [:]
    private(set) var unreadCount = 0
    private(set) var errorKey: String?
    private(set) var paginationErrorKey: String?
    private(set) var isLoadingMore = false
    private(set) var isMarkingAllRead = false
    private(set) var isUpdatingReadStatus = false

    let viewerID: UUID
    private let services: GlintServices
    private let pageSize = 30
    private var nextPage: Int?
    private var generation = UUID()
    private var unreadGeneration = UUID()

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
    }

    func load() async {
        let current = UUID()
        let countGeneration = UUID()
        generation = current
        unreadGeneration = countGeneration
        nextPage = nil
        notifications = []
        actorsByID = [:]
        state = .loading
        errorKey = nil
        paginationErrorKey = nil
        do {
            async let pageRequest = services.notifications.fetchNotifications(for: viewerID, page: 0, pageSize: pageSize)
            async let countRequest = services.notifications.unreadCount(for: viewerID)
            let (page, count) = try await (pageRequest, countRequest)
            guard generation == current else { return }
            notifications = page.items
            nextPage = page.nextPage
            if unreadGeneration == countGeneration { unreadCount = count }
            await loadActors(for: page.items, generation: current)
            guard generation == current else { return }
            state = notifications.isEmpty ? .empty : .ready
        } catch {
            guard generation == current else { return }
            state = .failed
            errorKey = "notifications.error.load"
        }
    }

    func refresh() async {
        let current = UUID()
        let countGeneration = UUID()
        generation = current
        unreadGeneration = countGeneration
        errorKey = nil
        paginationErrorKey = nil
        do {
            async let pageRequest = services.notifications.fetchNotifications(for: viewerID, page: 0, pageSize: pageSize)
            async let countRequest = services.notifications.unreadCount(for: viewerID)
            let (page, count) = try await (pageRequest, countRequest)
            guard generation == current else { return }
            notifications = page.items
            nextPage = page.nextPage
            if unreadGeneration == countGeneration { unreadCount = count }
            await loadActors(for: page.items, generation: current)
            guard generation == current else { return }
            state = notifications.isEmpty ? .empty : .ready
        } catch {
            guard generation == current else { return }
            errorKey = "notifications.error.load"
            if notifications.isEmpty { state = .failed }
        }
    }

    func loadMoreIfNeeded(current notification: GlintNotification) async {
        guard notification.id == notifications.last?.id, let nextPage, !isLoadingMore else { return }
        await loadPage(nextPage)
    }

    func retryLoadMore() async {
        guard let nextPage, !isLoadingMore else { return }
        await loadPage(nextPage)
    }

    private func loadPage(_ pageNumber: Int) async {
        guard !isLoadingMore else { return }
        let expectedGeneration = generation
        isLoadingMore = true
        paginationErrorKey = nil
        defer { isLoadingMore = false }
        do {
            let page = try await services.notifications.fetchNotifications(for: viewerID, page: pageNumber, pageSize: pageSize)
            guard generation == expectedGeneration else { return }
            try Task.checkCancellation()
            notifications.append(contentsOf: page.items)
            nextPage = page.nextPage
            await loadActors(for: page.items, generation: expectedGeneration)
        } catch is CancellationError {
            return
        } catch {
            guard generation == expectedGeneration else { return }
            paginationErrorKey = "notifications.error.load"
        }
    }

    func markAsRead(_ notification: GlintNotification) async -> Bool {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return false }
        if notifications[index].isRead { return true }
        guard !isMarkingAllRead, !isUpdatingReadStatus else { return false }
        isUpdatingReadStatus = true
        defer { isUpdatingReadStatus = false }
        notifications[index].isRead = true
        unreadCount = max(0, unreadCount - 1)
        unreadGeneration = UUID()
        do {
            try await services.notifications.markAsRead(notification.id, for: viewerID)
            await refreshUnreadCount()
            return true
        } catch {
            if let current = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[current].isRead = false
            }
            await refreshUnreadCount()
            errorKey = "notifications.error.markRead"
            return true
        }
    }

    func markAllAsRead() async {
        guard unreadCount > 0, !isMarkingAllRead, !isUpdatingReadStatus else { return }
        isMarkingAllRead = true
        defer { isMarkingAllRead = false }
        let oldNotifications = notifications
        notifications.indices.forEach { notifications[$0].isRead = true }
        unreadCount = 0
        unreadGeneration = UUID()
        errorKey = nil
        do {
            try await services.notifications.markAllAsRead(for: viewerID)
            await refreshUnreadCount()
        } catch {
            notifications = oldNotifications
            await refreshUnreadCount()
            errorKey = "notifications.error.markRead"
        }
    }

    func refreshUnreadCount() async {
        let current = UUID()
        unreadGeneration = current
        do {
            let count = try await services.notifications.unreadCount(for: viewerID)
            guard unreadGeneration == current else { return }
            unreadCount = count
        } catch {
            guard unreadGeneration == current else { return }
            errorKey = "notifications.error.count"
        }
    }

    private func loadActors(for items: [GlintNotification], generation expected: UUID) async {
        for actorID in Set(items.map(\.actorID)) where actorsByID[actorID] == nil {
            guard generation == expected else { return }
            guard var actor = try? await services.users.fetchUser(id: actorID, viewedBy: viewerID) else { continue }
            if services.subscriptions is MockSubscriptionService,
               let tier = try? await services.subscriptions.currentTier(for: actorID), tier != .glintPlus {
                actor.avatarShape = .circle
            }
            actorsByID[actorID] = actor
        }
    }
}
