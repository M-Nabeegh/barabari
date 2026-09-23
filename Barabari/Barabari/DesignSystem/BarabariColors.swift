import SwiftUI

enum BarabariColors {
    // Barabari uses a quiet obsidian and graphite foundation with a soft mint
    // status color. Primary actions use ink in light mode and pearl in dark
    // mode so hierarchy stays clear without a decorative accent hue.
    static let brandObsidian = Color(uiColor: UIColor(hex: 0x090A0C))
    static let brandGraphite = Color(uiColor: UIColor(hex: 0x15171A))
    static let brandMint = Color(uiColor: UIColor(hex: 0x92E6BE))

    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x090A0C) : UIColor(hex: 0xF5F6F7)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x15171A) : .white
    })
    static let raised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x22252A) : UIColor(hex: 0xE8EBEE)
    })

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xF2F4F5) : UIColor(hex: 0x111315)
    })
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x090A0C) : .white
    })
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x92E6BE) : UIColor(hex: 0x16724D)
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
