import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum ExploreState: Equatable {
        case loading
        case ready
        case failed
    }

    let viewerID: UUID
    private let services: GlintServices
    private let defaults: UserDefaults
    private let legacySharedRecentKey = "glint.search.recent.v1"
    private var recentKey: String { "glint.search.recent.v1.\(viewerID.uuidString.lowercased())" }
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = UUID()
    private var exploreGeneration = UUID()

    private(set) var query = ""
    private(set) var people: [GlintUser] = []
    private(set) var recentSearches: [String] = []
    private(set) var explorePosts: [GlintPost] = []
    private(set) var authorsByID: [UUID: GlintUser] = [:]
    private(set) var exploreState: ExploreState = .loading
    private(set) var peopleState: ExploreState = .ready
    private(set) var peopleErrorKey: String?
    private(set) var exploreErrorKey: String?

    init(viewerID: UUID, services: GlintServices, defaults: UserDefaults = .standard) {
        self.viewerID = viewerID
        self.services = services
        self.defaults = defaults
        defaults.removeObject(forKey: legacySharedRecentKey)
        recentSearches = defaults.stringArray(forKey: recentKey) ?? []
    }

    func loadExplore() async {
        let generation = UUID()
        exploreGeneration = generation
        exploreState = .loading
        exploreErrorKey = nil
        do {
            let page = try await services.posts.fetchExplorePosts(for: viewerID, page: 0, pageSize: 30)
            var loadedAuthors: [UUID: GlintUser] = [:]
            for authorID in Set(page.items.map(\.authorID)) {
                loadedAuthors[authorID] = try await services.users.fetchUser(id: authorID, viewedBy: viewerID)
            }
            guard exploreGeneration == generation else { return }
            explorePosts = page.items
            authorsByID = loadedAuthors
            exploreState = .ready
        } catch {
            guard exploreGeneration == generation else { return }
            exploreState = .failed
            exploreErrorKey = error is GlintServiceError ? "search.error.explore" : "search.error.generic"
        }
    }

    func refreshAfterPrivacyChange() async {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
            updateQuery(query)
        }
        await loadExplore()
    }

    func updateQuery(_ value: String) {
        query = value
        searchTask?.cancel()
        searchGeneration = UUID()
        let generation = searchGeneration
        people = []
        peopleErrorKey = nil
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            peopleState = .ready
            return
        }
        peopleState = .loading
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                let result = try await self.services.users.searchUsers(query: value, viewedBy: self.viewerID, limit: 30)
                guard !Task.isCancelled, self.searchGeneration == generation else { return }
                var displayUsers: [GlintUser] = []
                for var user in result where user.id != self.viewerID {
                    guard !Task.isCancelled, self.searchGeneration == generation else { return }
                    if self.services.subscriptions is MockSubscriptionService {
                        let tier = try await self.services.subscriptions.currentTier(for: user.id)
                        if tier != .glintPlus { user.avatarShape = .circle }
                    }
                    displayUsers.append(user)
                }
                guard !Task.isCancelled, self.searchGeneration == generation else { return }
                self.people = displayUsers
                self.peopleState = .ready
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.searchGeneration == generation else { return }
                self.peopleState = .failed
                self.peopleErrorKey = error is GlintServiceError ? "search.error.people" : "search.error.generic"
            }
        }
    }

    func recordSearch(_ value: String) {
        let search = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard search.count >= 2 else { return }
        recentSearches.removeAll { $0.localizedCaseInsensitiveCompare(search) == .orderedSame }
        recentSearches.insert(search, at: 0)
        recentSearches = Array(recentSearches.prefix(8))
        defaults.set(recentSearches, forKey: recentKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults.removeObject(forKey: recentKey)
    }
}
