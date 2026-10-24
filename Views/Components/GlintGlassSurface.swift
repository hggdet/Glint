import SwiftUI

struct GlintGlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    init(
        cornerRadius: CGFloat = 24,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
                .padding(18)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
