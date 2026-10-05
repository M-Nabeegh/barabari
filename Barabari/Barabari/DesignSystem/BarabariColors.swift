import SwiftUI

enum BarabariColors {
    // Grouped system surfaces keep the app feeling native, while a single
    // emerald signature colour carries the brand through cards, tints and
    // primary actions.
    static let brandObsidian = Color(uiColor: UIColor(hex: 0x050807))
    static let brandGraphite = Color(uiColor: UIColor(hex: 0x141917))
    static let brandMint = Color(uiColor: UIColor(hex: 0x7EF0C0))
    static let brandEmerald = Color(uiColor: UIColor(hex: 0x10B981))
    static let brandForest = Color(uiColor: UIColor(hex: 0x053D2C))

    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x000000) : UIColor(hex: 0xF2F3F5)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x131515) : .white
    })
    static let raised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x232727) : UIColor(hex: 0xECEEF0)
    })
    static let hairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.07) : UIColor(white: 0, alpha: 0.05)
    })

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x34D399) : UIColor(hex: 0x059669)
    })
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x04120C) : .white
    })
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x4ADE80) : UIColor(hex: 0x15803D)
    })
    static let warning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xFBBF24) : UIColor(hex: 0xB45309)
    })
    static let danger = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xFF7A8A) : UIColor(hex: 0xE11D48)
    })

    /// Pairs used for member avatars, picked deterministically per person.
    static let avatarPalettes: [(Color, Color)] = [
        (Color(uiColor: UIColor(hex: 0x34D399)), Color(uiColor: UIColor(hex: 0x059669))),
        (Color(uiColor: UIColor(hex: 0x60A5FA)), Color(uiColor: UIColor(hex: 0x2563EB))),
        (Color(uiColor: UIColor(hex: 0xF9A8D4)), Color(uiColor: UIColor(hex: 0xDB2777))),
        (Color(uiColor: UIColor(hex: 0xFCD34D)), Color(uiColor: UIColor(hex: 0xD97706))),
        (Color(uiColor: UIColor(hex: 0xC4B5FD)), Color(uiColor: UIColor(hex: 0x7C3AED))),
        (Color(uiColor: UIColor(hex: 0x67E8F9)), Color(uiColor: UIColor(hex: 0x0891B2)))
    ]
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
