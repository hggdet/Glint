import Foundation

/// Avatar masks available to profiles. Non-circle masks are reserved for Glint+.
public enum AvatarShape: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case circle
    case roundedSquare
    case squircle
    case star
    case hexagon

    public var id: String { rawValue }

    public var requiresGlintPlus: Bool { self != .circle }
}
