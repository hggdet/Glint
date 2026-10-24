import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed
    }

    private(set) var state: LoadState = .loading
    private(set) var user: GlintUser?
    private(set) var posts: [GlintPost] = []
    private(set) var followRequests: [FollowRequest] = []
    private(set) var requestersByID: [UUID: GlintUser] = [:]
    private(set) var respondingToRequestID: UUID?
    private(set) var tier: GlintSubscriptionTier = .free
    private(set) var products: [SubscriptionProduct] = []
    private(set) var isLoadingPlans = false
    private(set) var isSaving = false
    private(set) var isProcessingPurchase = false
    private(set) var errorKey: String?
    private(set) var noticeKey: String?
    private(set) var plusErrorKey: String?
    private(set) var plusNoticeKey: String?

    let viewerID: UUID
    private let services: GlintServices
    var servicesForLists: GlintServices { services }
    private var loadGeneration = UUID()

    init(viewerID: UUID, services: GlintServices) {
        self.viewerID = viewerID
        self.services = services
    }

    var isMockSubscriptionService: Bool {
        services.subscriptions is MockSubscriptionService
    }

    func load() async {
        let generation = UUID()
        loadGeneration = generation
        state = .loading
        errorKey = nil
        do {
            async let fetchedUser = services.users.fetchUser(id: viewerID, viewedBy: viewerID)
            async let fetchedPosts = services.posts.fetchPosts(by: viewerID, for: viewerID, page: 0, pageSize: 100)
            async let currentTier = services.subscriptions.currentTier(for: viewerID)
            async let incomingRequests = services.users.pendingFollowRequests(for: viewerID)
            let (loadedUser, postPage, loadedTier, requests) = try await (fetchedUser, fetchedPosts, currentTier, incomingRequests)
            guard loadGeneration == generation else { return }
            user = loadedUser
            posts = postPage.items
            tier = loadedTier
            followRequests = requests
            requestersByID = await loadRequesters(requests)
            state = .ready
        } catch {
            guard loadGeneration == generation else { return }
            state = .failed
            errorKey = profileErrorKey(for: error)
        }
    }

    func retry() async { await load() }

    func refresh() async {
        let generation = UUID()
        loadGeneration = generation
        errorKey = nil
        do {
            async let fetchedUser = services.users.fetchUser(id: viewerID, viewedBy: viewerID)
            async let fetchedPosts = services.posts.fetchPosts(by: viewerID, for: viewerID, page: 0, pageSize: 100)
            async let currentTier = services.subscriptions.currentTier(for: viewerID)
            async let incomingRequests = services.users.pendingFollowRequests(for: viewerID)
            let (loadedUser, postPage, loadedTier, requests) = try await (fetchedUser, fetchedPosts, currentTier, incomingRequests)
            guard loadGeneration == generation else { return }
            user = loadedUser
            posts = postPage.items
            tier = loadedTier
            followRequests = requests
            requestersByID = await loadRequesters(requests)
            state = .ready
        } catch {
            guard loadGeneration == generation else { return }
            errorKey = profileErrorKey(for: error)
            if user == nil { state = .failed }
        }
    }

    func loadPlans() async {
        guard !isLoadingPlans else { return }
        isLoadingPlans = true
        plusErrorKey = nil
        defer { isLoadingPlans = false }
        do {
            products = try await services.subscriptions.availableProducts()
            if products.isEmpty { plusErrorKey = "plus.error.productsUnavailable" }
        } catch {
            plusErrorKey = profileErrorKey(for: error)
        }
    }

    func updateProfile(_ update: ProfileUpdate) async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        errorKey = nil
        let updatedUser = try await services.users.createOrUpdateProfile(userID: viewerID, update: update)
        user = updatedUser
        noticeKey = "profile.saved"
    }

    func purchase(productID: String) async {
        guard !isProcessingPurchase else { return }
        isProcessingPurchase = true
        plusErrorKey = nil
        plusNoticeKey = nil
        defer { isProcessingPurchase = false }
        do {
            let purchasedTier = try await services.subscriptions.purchase(productID: productID, for: viewerID)
            let verifiedTier = try await services.subscriptions.currentTier(for: viewerID)
            guard purchasedTier == .glintPlus, verifiedTier == .glintPlus else {
                throw GlintServiceError.subscriptionVerificationFailed
            }
            tier = verifiedTier
            plusNoticeKey = "plus.purchase.success"
        } catch {
            plusErrorKey = profileErrorKey(for: error)
        }
    }

    func restorePurchases() async {
        guard !isProcessingPurchase else { return }
        isProcessingPurchase = true
        plusErrorKey = nil
        plusNoticeKey = nil
        defer { isProcessingPurchase = false }
        do {
            let restoredTier = try await services.subscriptions.restorePurchases(for: viewerID)
            let verifiedTier = try await services.subscriptions.currentTier(for: viewerID)
            guard restoredTier == verifiedTier else { throw GlintServiceError.subscriptionVerificationFailed }
            tier = verifiedTier
            plusNoticeKey = restoredTier == .glintPlus ? "plus.restore.success" : "plus.restore.empty"
        } catch {
            plusErrorKey = profileErrorKey(for: error)
        }
    }

    func respondToFollowRequest(_ request: FollowRequest, accept: Bool) async {
        guard respondingToRequestID == nil else { return }
        respondingToRequestID = request.id
        defer { respondingToRequestID = nil }
        errorKey = nil
        do {
            if accept {
                try await services.users.acceptFollowRequest(request.id, by: viewerID)
            } else {
                try await services.users.rejectFollowRequest(request.id, by: viewerID)
            }
            followRequests.removeAll { $0.id == request.id }
            requestersByID.removeValue(forKey: request.requesterID)
            if accept { await refresh() }
        } catch {
            errorKey = "profile.followRequests.error"
        }
    }

    func clearMessages() {
        errorKey = nil
        noticeKey = nil
        plusErrorKey = nil
        plusNoticeKey = nil
    }

    private func loadRequesters(_ requests: [FollowRequest]) async -> [UUID: GlintUser] {
        var result: [UUID: GlintUser] = [:]
        for requesterID in Set(requests.map(\.requesterID)) {
            if var user = try? await services.users.fetchUser(id: requesterID, viewedBy: viewerID) {
                if services.subscriptions is MockSubscriptionService {
                    if (try? await services.subscriptions.currentTier(for: requesterID)) != .glintPlus {
                        user.avatarShape = .circle
                    }
                }
                result[requesterID] = user
            }
        }
        return result
    }

    private func profileErrorKey(for error: Error) -> String {
        guard let serviceError = error as? GlintServiceError else { return "profile.error.generic" }
        switch serviceError {
        case .usernameUnavailable: return "profile.error.usernameTaken"
        case .invalidUsername: return "profile.error.invalidUsername"
        case .emptyDisplayName: return "profile.error.displayNameRequired"
        case .glintPlusRequired: return "profile.error.plusRequired"
        case .subscriptionProductUnavailable: return "plus.error.productsUnavailable"
        case .subscriptionCancelled: return "plus.purchase.cancelled"
        case .subscriptionPending: return "plus.purchase.pending"
        case .subscriptionVerificationFailed: return "plus.error.verification"
        default: return "profile.error.generic"
        }
    }
}
