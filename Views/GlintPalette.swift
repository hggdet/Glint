import SwiftUI
import UIKit

enum GlintPalette {
    static let accent = Color(red: 1.0, green: 0.31, blue: 0.42)
    static let secondaryAccent = Color(red: 0.94, green: 0.22, blue: 0.63)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.045, blue: 0.075, alpha: 1)
            : UIColor(red: 0.97, green: 0.955, blue: 0.975, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.11, blue: 0.16, alpha: 1)
            : UIColor(red: 0.91, green: 0.88, blue: 0.94, alpha: 1)
    })
}
