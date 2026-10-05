import SwiftUI

struct ContentView: View {
    let environment: AppEnvironment

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("barabari.hasOnboarded") private var hasOnboarded = false
    @StateObject private var lock = AppLock.shared
    @State private var showsSplash: Bool
    @State private var isObscured = false

    /// UI tests drive the ledger directly, so they skip the splash, intro and lock.
    private let isUITesting: Bool

    init(environment: AppEnvironment) {
        self.environment = environment
        let uiTesting = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }
        isUITesting = uiTesting
        _showsSplash = State(initialValue: !uiTesting)
    }

    var body: some View {
        ZStack {
            RootView(environment: environment)

            if !hasOnboarded && !isUITesting && !showsSplash {
                OnboardingView {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) { hasOnboarded = true }
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .bottom).combined(with: .opacity)))
                .zIndex(2)
            }

            if lock.isLocked && !isUITesting && !showsSplash {
                LockScreenView(lock: lock)
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
                    .zIndex(3)
            }

            if isObscured && lock.isEnabled && !lock.isLocked {
                PrivacyShield()
                    .transition(.opacity)
                    .zIndex(4)
            }

            if showsSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .zIndex(5)
            }
        }
        .task {
            guard showsSplash else { return }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeInOut(duration: 0.5)) { showsSplash = false }
        }
        .onChange(of: scenePhase) { _, phase in
            guard !isUITesting else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isObscured = phase != .active
            }
            if phase == .background {
                lock.lockIfNeeded()
            }
        }
    }
}
