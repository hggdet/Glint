import Foundation

public struct PageResult<Item: Sendable>: Sendable {
    public var items: [Item]
    public var nextPage: Int?

    public init(items: [Item], nextPage: Int?) {
        self.items = items
        self.nextPage = nextPage
    }

    public var hasMore: Bool { nextPage != nil }
}
