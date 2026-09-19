import SwiftUI

enum BarabariColors {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x080D10) : UIColor(hex: 0xF5F7F8)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x111A1E) : .white
    })
    static let raised = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x18242A) : UIColor(hex: 0xE9EEF0)
    })

    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let accent = Color(uiColor: UIColor(hex: 0x087E8B))
    static let success = Color(uiColor: UIColor(hex: 0x16805B))
    static let warning = Color(uiColor: UIColor(hex: 0xB86B00))
    static let danger = Color(uiColor: UIColor(hex: 0xB3264D))
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
