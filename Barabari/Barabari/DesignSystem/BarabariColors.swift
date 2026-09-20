import SwiftUI

enum BarabariColors {
    // The app icon is built around a deep indigo field, electric blue detail,
    // and a mint balance mark. Keep those hues in one place so the product
    // feels like one system instead of a collection of unrelated screens.
    static let brandNavy = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x070D32) : UIColor(hex: 0x111A4B)
    })
    static let brandIndigo = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8D9AFF) : UIColor(hex: 0x3045D6)
    })
    static let brandMint = Color(uiColor: UIColor(hex: 0x98F0C2))

    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x070D32) : UIColor(hex: 0xF5F7FF)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x101A4B) : .white
    })
    static let raised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x182660) : UIColor(hex: 0xE8ECFF)
    })

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    // Accent foregrounds have separate variants so a filled control remains
    // readable in both appearances.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x8D9AFF) : UIColor(hex: 0x3045D6)
    })
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x070D32) : .white
    })
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x98F0C2) : UIColor(hex: 0x16724D)
    })
    static let warning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xF0B45B) : UIColor(hex: 0x9C5600)
    })
    static let danger = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xFF9AB2) : UIColor(hex: 0xAD1E45)
    })
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
