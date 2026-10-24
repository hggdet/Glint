import SwiftUI

struct GlintGlassButton<Label: View>: View {
    var prominent = false
    var tint: Color = GlintPalette.accent
    var action: () -> Void
    @ViewBuilder var label: Label

    init(
        prominent: Bool = false,
        tint: Color = GlintPalette.accent,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.prominent = prominent
        self.tint = tint
        self.action = action
        self.label = label()
    }

    var body: some View {
        Group {
            if prominent {
                Button(action: action) { label }.buttonStyle(.glassProminent)
            } else {
                Button(action: action) { label }.buttonStyle(.glass)
            }
        }
        .tint(tint)
    }
}

struct GlintIconButton: View {
    let systemName: String
    let accessibilityTitle: LocalizedStringKey
    var prominent = false
    var action: () -> Void

    var body: some View {
        GlintGlassButton(prominent: prominent, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel(accessibilityTitle)
    }
}
