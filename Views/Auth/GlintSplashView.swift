import SwiftUI

struct GlintSplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("✦")
                .font(.system(size: 58, weight: .medium, design: .rounded))
                .foregroundStyle(GlintPalette.accent)
                .accessibilityHidden(true)
            Text("app.name")
                .font(.largeTitle.weight(.bold))
            Text("auth.splash.tagline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.regular)
                .tint(GlintPalette.accent)
                .padding(.top, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("app.name"))
        .accessibilityValue(Text("common.loading"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlintPalette.background.ignoresSafeArea())
    }
}
