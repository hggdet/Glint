import Foundation

@MainActor
public protocol MockNotificationEventSink: AnyObject {
    func recordNotification(
        recipientID: UUID,
        event: GlintNotificationEvent,
        actorID: UUID,
        destination: GlintNotificationDestination
    )
}

@MainActor
public final class MockNotificationStore: MockNotificationEventSink {
    private let defaults: UserDefaults
    private static let eventsKey = "glint.mock.notifications.events.v1"
    private var events: [GlintNotification]
    private var loadFailed = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.eventsKey) {
            do { events = try JSONDecoder().decode([GlintNotification].self, from: data) }
            catch {
                events = MockData.notifications
                loadFailed = true
            }
        } else {
            events = MockData.notifications
        }
        for index in events.indices {
            let readIDs = Set(defaults.stringArray(forKey: Self.readKey(for: events[index].recipientID)) ?? [])
            if readIDs.contains(events[index].id.uuidString) { events[index].isRead = true }
        }
        defaults.removeObject(forKey: "glint.mock.notifications.read.v1")
    }

    public func recordNotification(
        recipientID: UUID,
        event: GlintNotificationEvent,
        actorID: UUID,
        destination: GlintNotificationDestination
    ) {
        guard recipientID != actorID, !loadFailed else { return }
        events.insert(
            GlintNotification(recipientID: recipientID, event: event, actorID: actorID, destination: destination),
            at: 0
        )
        do { try persistEvents() }
        catch { events.removeFirst() }
    }

    public func notifications(for recipientID: UUID) throws -> [GlintNotification] {
        guard !loadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        return events.filter { $0.recipientID == recipientID }
    }

    public func markAsRead(_ notificationID: UUID, for recipientID: UUID) throws {
        guard !loadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        guard let index = events.firstIndex(where: { $0.id == notificationID && $0.recipientID == recipientID }) else { return }
        let previous = events[index]
        events[index].isRead = true
        do { try persistEvents() }
        catch {
            events[index] = previous
            throw error
        }
        let readIDs = events.filter { $0.recipientID == recipientID && $0.isRead }.map { $0.id.uuidString }
        defaults.set(readIDs, forKey: Self.readKey(for: recipientID))
    }

    public func markAllAsRead(for recipientID: UUID) throws {
        guard !loadFailed else { throw GlintServiceError.localDataPersistenceFailed }
        let previous = events
        for index in events.indices where events[index].recipientID == recipientID {
            events[index].isRead = true
        }
        do { try persistEvents() }
        catch {
            events = previous
            throw error
        }
        let readIDs = events.filter { $0.recipientID == recipientID && $0.isRead }.map { $0.id.uuidString }
        defaults.set(readIDs, forKey: Self.readKey(for: recipientID))
    }

    private func persistEvents() throws {
        do { defaults.set(try JSONEncoder().encode(events), forKey: Self.eventsKey) }
        catch {
            loadFailed = true
            throw GlintServiceError.localDataPersistenceFailed
        }
    }

    private static func readKey(for recipientID: UUID) -> String {
        "glint.mock.notifications.read.v1.\(recipientID.uuidString.lowercased())"
    }
}
