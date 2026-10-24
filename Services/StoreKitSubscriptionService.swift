import Foundation
import StoreKit

/// StoreKit 2 implementation for Xcode StoreKit testing and a future App Store configuration.
/// The app's default demo composition still injects MockSubscriptionService.
@MainActor
public final class StoreKitSubscriptionService: SubscriptionService {
    public static let monthlyProductID = "glint_plus_monthly"
    public static let yearlyProductID = "glint_plus_yearly"
    public static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    public init() {}

    public func availableProducts() async throws -> [SubscriptionProduct] {
        let products = try await Product.products(for: Self.productIDs)
        return products
            .filter { $0.type == .autoRenewable }
            .sorted { $0.id < $1.id }
            .map { product in
                let period: SubscriptionPeriod = product.subscription?.subscriptionPeriod.unit == .year ? .yearly : .monthly
                return SubscriptionProduct(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    period: period
                )
            }
    }

    public func currentTier(for userID: UUID) async throws -> GlintSubscriptionTier {
        _ = userID // Entitlements are verified with StoreKit; account binding belongs on the future backend.
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  !isRevoked(transaction) else { continue }
            return .glintPlus
        }
        return .free
    }

    public func purchase(productID: String, for userID: UUID) async throws -> GlintSubscriptionTier {
        _ = userID
        guard Self.productIDs.contains(productID) else {
            throw GlintServiceError.subscriptionProductUnavailable
        }
        let products = try await Product.products(for: [productID])
        guard let product = products.first, product.type == .autoRenewable else {
            throw GlintServiceError.subscriptionProductUnavailable
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            guard transaction.productID == productID, !isRevoked(transaction) else {
                throw GlintServiceError.subscriptionVerificationFailed
            }
            await transaction.finish()
            return .glintPlus
        case .pending:
            throw GlintServiceError.subscriptionPending
        case .userCancelled:
            throw GlintServiceError.subscriptionCancelled
        @unknown default:
            throw GlintServiceError.unavailable
        }
    }

    public func restorePurchases(for userID: UUID) async throws -> GlintSubscriptionTier {
        _ = userID
        try await AppStore.sync()
        return try await currentTier(for: userID)
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction): return transaction
        case .unverified: throw GlintServiceError.subscriptionVerificationFailed
        }
    }

    private func isRevoked(_ transaction: Transaction) -> Bool {
        transaction.revocationDate != nil
    }
}
