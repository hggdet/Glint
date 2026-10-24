import SwiftUI
import UIKit

struct GlintAvatarView: View {
    let user: GlintUser
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let fileURL = user.avatarFileURL, let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let assetName = user.avatarAssetName, let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [GlintPalette.accent.opacity(0.92), GlintPalette.secondaryAccent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(String(user.displayName.prefix(1)))
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(GlintAvatarMask(shape: user.avatarShape))
        .overlay(GlintAvatarMask(shape: user.avatarShape).stroke(.white.opacity(0.22), lineWidth: 1))
        .accessibilityLabel(Text(user.displayName))
    }
}

private struct GlintAvatarMask: Shape {
    let shape: AvatarShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Path(ellipseIn: rect)
        case .roundedSquare:
            return RoundedRectangle(cornerRadius: rect.width * 0.25, style: .continuous).path(in: rect)
        case .squircle:
            return superellipse(in: rect)
        case .star:
            return polygon(in: rect, sides: 10, innerRadiusRatio: 0.48)
        case .hexagon:
            return polygon(in: rect, sides: 6, innerRadiusRatio: 1)
        }
    }

    private func polygon(in rect: CGRect, sides: Int, innerRadiusRatio: CGFloat) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        var path = Path()
        for index in 0..<sides {
            let radius = index.isMultiple(of: 2) ? outerRadius : outerRadius * innerRadiusRatio
            let angle = CGFloat(index) * 2 * .pi / CGFloat(sides) - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func superellipse(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width * 0.5
        let radiusY = rect.height * 0.5
        var path = Path()
        for index in 0...64 {
            let angle = CGFloat(index) * 2 * .pi / 64
            let cosine = cos(angle)
            let sine = sin(angle)
            let x = (cosine >= 0 ? 1 : -1) * pow(abs(cosine), 0.5) * radiusX
            let y = (sine >= 0 ? 1 : -1) * pow(abs(sine), 0.5) * radiusY
            let point = CGPoint(x: center.x + x, y: center.y + y)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
