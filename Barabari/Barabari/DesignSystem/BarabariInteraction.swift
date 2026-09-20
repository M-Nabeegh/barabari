import SwiftUI
import UIKit

enum BarabariInteraction {
    static let minimumHitSize: CGFloat = 44
    static let hapticsUserDefaultsKey = "barabari.hapticsEnabled"

    enum Feedback {
        case selection
        case success
        case error
    }

    static var hapticsEnabled: Bool {
        guard let value = UserDefaults.standard.object(forKey: hapticsUserDefaultsKey) as? Bool else {
            return true
        }
        return value
    }

    static func trigger(_ feedback: Feedback, enabled: Bool = hapticsEnabled) {
        guard enabled, !UIAccessibility.isReduceMotionEnabled else { return }

        switch feedback {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

extension View {
    func barabariHitTarget(minHeight: CGFloat = BarabariInteraction.minimumHitSize) -> some View {
        frame(minHeight: max(minHeight, BarabariInteraction.minimumHitSize))
            .contentShape(Rectangle())
    }
}
