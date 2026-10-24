import SwiftUI

struct GlintSweepModifier<Mask: Shape>: ViewModifier {
    let mask: Mask
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweepProgress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        let stripWidth = max(1, geometry.size.width * 0.22)
                        ZStack(alignment: .leading) {
                            Color.clear
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .white.opacity(0.58), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: stripWidth, height: geometry.size.height * 1.5)
                            .rotationEffect(.degrees(-14))
                            .offset(x: sweepProgress * (geometry.size.width + stripWidth) - stripWidth)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                        .mask(mask.fill(.white))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            }
            .onAppear(perform: beginSweep)
            .onChange(of: reduceMotion) { _, shouldReduce in
                if shouldReduce {
                    sweepProgress = 0
                } else {
                    beginSweep()
                }
            }
    }

    private func beginSweep() {
        guard !reduceMotion else { return }
        sweepProgress = 0
        withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
            sweepProgress = 1
        }
    }
}

extension View {
    func glintSweep<Mask: Shape>(in mask: Mask) -> some View {
        modifier(GlintSweepModifier(mask: mask))
    }
}
