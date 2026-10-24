import Foundation

@MainActor
public final class MockSubscriptionService: SubscriptionService {
    private var tierByUserID: [UUID: GlintSubscriptionTier]

    public init() {
        tierByUserID = Dictionary(uniqueKeysWithValues: MockData.users.map { ($0.id, .free) })
        // Seed a few demo entitlements here, independently from profile data.
        for userID in [MockData.maya.id, MockData.leo.id, MockData.noah.id, MockData.zara.id] {
            tierByUserID[userID] = .glintPlus
        }
    }

    public func availableProducts() async throws -> [SubscriptionProduct] {
        [
            SubscriptionProduct(id: "glint_plus_monthly", displayName: "Glint+ Monthly", displayPrice: "$2.99", period: .monthly),
            SubscriptionProduct(id: "glint_plus_yearly", displayName: "Glint+ Yearly", displayPrice: "$24.99", period: .yearly)
        ]
    }

    public func currentTier(for userID: UUID) async throws -> GlintSubscriptionTier {
        tierByUserID[userID] ?? .free
    }

    public func purchase(productID: String, for userID: UUID) async throws -> GlintSubscriptionTier {
        guard ["glint_plus_monthly", "glint_plus_yearly"].contains(productID) else {
            throw GlintServiceError.invalidInput("Unknown subscription product.")
        }
        // Mock only: this does not contact the App Store or charge the user.
        tierByUserID[userID] = .glintPlus
        return .glintPlus
    }

    public func restorePurchases(for userID: UUID) async throws -> GlintSubscriptionTier {
        tierByUserID[userID] ?? .free
    }
}
