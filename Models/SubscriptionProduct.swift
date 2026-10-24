import Foundation

public enum SubscriptionPeriod: String, Codable, Equatable, Sendable {
    case monthly
    case yearly
}

public struct SubscriptionProduct: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var displayPrice: String
    public var period: SubscriptionPeriod

    public init(id: String, displayName: String, displayPrice: String, period: SubscriptionPeriod) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.period = period
    }
}
