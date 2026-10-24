import SwiftUI
import UIKit

enum GlintActionKind: Equatable, Sendable {
    case like
    case comment
    case share
    case save
}

struct GlintActionButton: View {
    let kind: GlintActionKind
    let title: LocalizedStringKey
    var isActive = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationPhase = false
    @State private var animationResetTask: Task<Void, Never>?

    private var symbol: String {
        switch kind {
        case .like: return isActive ? "heart.fill" : "heart"
        case .comment: return "bubble.right"
        case .share: return "arrowshape.turn.up.right"
        case .save: return isActive ? "bookmark.fill" : "bookmark"
        }
    }

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            guard !reduceMotion else { return }
            animationResetTask?.cancel()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.56)) {
                animationPhase = true
            }
            animationResetTask = Task {
                try? await Task.sleep(for: .milliseconds(360))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    animationPhase = false
                }
            }
        } label: {
            ZStack {
                actionIcon

                if kind == .like && animationPhase {
                    ForEach(0..<8, id: \.self) { index in
                        let angle = CGFloat(index) * 2 * .pi / 8
                        Circle()
                            .fill(index.isMultiple(of: 2) ? GlintPalette.accent : GlintPalette.secondaryAccent)
                            .frame(width: 3, height: 3)
                            .offset(x: cos(angle) * 17, y: sin(angle) * 17)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(width: 44, height: 44)
            .glassEffect(.regular, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private var actionIcon: some View {
        let icon = Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isActive ? GlintPalette.accent : .primary)
            .scaleEffect(symbolScale)
            .scaleEffect(x: kind == .comment && animationPhase ? 1.14 : 1, y: kind == .comment && animationPhase ? 0.88 : 1)
            .rotationEffect(.degrees(kind == .share && animationPhase ? -16 : 0))
            .rotationEffect(.degrees(kind == .save && animationPhase ? 18 : 0))
            .offset(y: kind == .share && animationPhase ? -12 : kind == .save && animationPhase ? 7 : 0)

        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.bounce, value: isActive)
        }
    }

    private var symbolScale: CGFloat {
        guard animationPhase else { return 1 }
        switch kind {
        case .like: return 1.3
        case .comment: return 1.17
        case .share: return 0.92
        case .save: return 1.08
        }
    }
}
