import Foundation

@MainActor
public protocol SubscriptionService: AnyObject, Sendable {
    func availableProducts() async throws -> [SubscriptionProduct]
    func currentTier(for userID: UUID) async throws -> GlintSubscriptionTier
    func purchase(productID: String, for userID: UUID) async throws -> GlintSubscriptionTier
    func restorePurchases(for userID: UUID) async throws -> GlintSubscriptionTier
}
