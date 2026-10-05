import Combine
import LocalAuthentication
import SwiftUI

/// Optional Face ID / passcode lock for the whole app.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()
    static let enabledKey = "barabari.appLockEnabled"

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    /// Face ID, Touch ID or Optic ID, whichever this device offers.
    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    var biometrySymbol: String {
        switch biometryName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock.fill"
        }
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    /// Turns the lock on only after the person proves they can unlock it.
    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            isEnabled = false
            return
        }
        if await authenticate(reason: "Turn on \(biometryName) for Barabari") {
            isEnabled = true
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate(reason: "Unlock your Barabari ledger") {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { isLocked = false }
        }
    }

    private func authenticate(reason: String) async -> Bool {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = "Set a passcode on this iPhone to use the lock."
            return false
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            lastError = nil
            return success
        } catch {
            lastError = nil
            return false
        }
    }
}

struct LockScreenView: View {
    @ObservedObject var lock: AppLock
    @State private var pulse = false

    var body: some View {
        ZStack {
            BarabariMeshBackground(tone: .graphite)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.3).ignoresSafeArea())

            VStack(spacing: 22) {
                Spacer()
                BarabariMark(size: 88, animate: false)
                Text("Barabari is locked")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if let error = lock.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(lock.biometryName)", systemImage: lock.biometrySymbol)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Capsule())
                        .symbolEffect(.pulse, isActive: lock.isAuthenticating)
                }
                .buttonStyle(.pressable)
                .glassEffect(.clear.interactive(), in: .capsule)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await lock.unlock() }
    }
}

/// Blurs the app in the App Switcher so balances never leak.
struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            BarabariMark(size: 72, animate: false)
        }
    }
}
