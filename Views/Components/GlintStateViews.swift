import SwiftUI

struct GlintLoadingState: View {
    let lineCount: Int

    init(lineCount: Int = 3) {
        self.lineCount = max(1, lineCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<lineCount, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle().fill(.quaternary).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                            .frame(width: index.isMultiple(of: 2) ? 150 : 110, height: 12)
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(height: 10)
                    }
                }
                .redacted(reason: .placeholder)
            }
        }
        .padding(18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("common.loading"))
    }
}

struct GlintEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(GlintPalette.accent)
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .accessibilityElement(children: .combine)
    }
}

struct GlintErrorState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let retryTitle: LocalizedStringKey
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Label(retryTitle, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .accessibilityElement(children: .contain)
    }
}
