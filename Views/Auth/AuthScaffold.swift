import SwiftUI
import UIKit

struct AuthScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let content: Content

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("✦")
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .foregroundStyle(GlintPalette.accent)
                        .accessibilityHidden(true)
                    Text("app.name")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                GlassEffectContainer(spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        content
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [GlintPalette.background, GlintPalette.background.opacity(0.82), GlintPalette.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct AuthTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
                    .textContentType(contentType)
            } else {
                TextField(title, text: $text)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard == .emailAddress)
            }
        }
        .font(.body)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct AuthPrimaryButton: View {
    let title: LocalizedStringKey
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isWorking { ProgressView().tint(.white) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(GlintPalette.accent)
        .disabled(isWorking)
    }
}

struct AuthFeedback: View {
    let errorKey: String?
    let noticeKey: String?

    var body: some View {
        if let errorKey {
            Label {
                Text(LocalizedStringKey(errorKey))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
        } else if let noticeKey {
            Label {
                Text(LocalizedStringKey(noticeKey))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
                .font(.footnote)
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
