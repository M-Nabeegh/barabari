import SwiftUI

// MARK: - Brand mark

/// The Barabari "equals" mark: two bars that slide in and settle level.
struct BarabariMark: View {
    var size: CGFloat = 96
    var animate = true

    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(uiColor: UIColor(hex: 0x34D399)), Color(uiColor: UIColor(hex: 0x047857))],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: BarabariColors.brandEmerald.opacity(0.5), radius: size * 0.25, y: size * 0.1)

            VStack(spacing: size * 0.12) {
                Capsule()
                    .fill(.white)
                    .frame(width: size * 0.5, height: size * 0.12)
                    .offset(x: settled ? 0 : -size * 0.18)
                    .rotationEffect(.degrees(settled ? 0 : -14))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: size * 0.5, height: size * 0.12)
                    .offset(x: settled ? 0 : size * 0.18)
                    .rotationEffect(.degrees(settled ? 0 : 14))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animate, !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.15)) { settled = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Splash

struct SplashView: View {
    @State private var appear = false
    @State private var ring = false

    var body: some View {
        ZStack {
            BarabariMeshBackground(tone: .emerald)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.35).ignoresSafeArea())

            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 1.5)
                .frame(width: 160, height: 160)
                .scaleEffect(ring ? 2.4 : 0.8)
                .opacity(ring ? 0 : 1)

            VStack(spacing: 18) {
                BarabariMark(size: 104)
                    .scaleEffect(appear ? 1 : 0.6)
                    .opacity(appear ? 1 : 0)
                Text("Barabari")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appear = true }
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) { ring = true }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    let finish: () -> Void

    @ObservedObject private var metadata = LedgerMetadata.shared
    @State private var page = 0
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private let pageCount = 4

    var body: some View {
        ZStack {
            BarabariMeshBackground(tone: .emerald)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pageCount - 1 {
                        Button("Skip") { withAnimation(pageAnimation) { page = pageCount - 1 } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(.clear.interactive(), in: .capsule)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, BarabariSpacing.screen)

                TabView(selection: $page) {
                    OnboardingPage(
                        title: "Split fairly.",
                        message: "Trips, flats, dinners — Barabari keeps every rupee between friends calm and clear."
                    ) { active in
                        OrbitingFriends(active: active)
                    }
                    .tag(0)

                    OnboardingPage(
                        title: "Every rupee, clear.",
                        message: "Exact or equal splits, smart categories, and a balance that always adds up."
                    ) { active in
                        CountingBalance(active: active)
                    }
                    .tag(1)

                    OnboardingPage(
                        title: "Settle your way.",
                        message: "Record Raast, Easypaisa, JazzCash, bank or cash payments. Barabari never touches your money."
                    ) { active in
                        FloatingMethods(active: active)
                    }
                    .tag(2)

                    nameStep
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
                    .padding(.horizontal, BarabariSpacing.screen)
                    .padding(.bottom, 12)
            }
        }
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: page)
    }

    private var pageAnimation: Animation { .spring(response: 0.55, dampingFraction: 0.85) }

    private var nameStep: some View {
        VStack(spacing: 24) {
            Spacer()
            MemberAvatar(name: name.isEmpty ? "?" : name, seed: AppEnvironment.demoUserID, size: nameFocused ? 76 : 110)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: nameFocused)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .scaleEffect(name.isEmpty ? 0.94 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.55), value: name.isEmpty)
            VStack(spacing: 10) {
                Text("What should we call you?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Friends in your groups see this name on shared expenses and reminders.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("Your name", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .frame(minHeight: 56)
                .padding(.horizontal, 20)
                .glassEffect(.clear.interactive(), in: .capsule)
                .onSubmit(complete)
                .accessibilityIdentifier("onboarding-name")
            Spacer()
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
    }

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index == page ? 1 : 0.35))
                        .frame(width: index == page ? 26 : 8, height: 8)
                }
            }
            .animation(pageAnimation, value: page)

            Button {
                if page < pageCount - 1 {
                    withAnimation(pageAnimation) { page += 1 }
                } else {
                    complete()
                }
            } label: {
                Text(page < pageCount - 1 ? "Continue" : "Get started")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(BarabariColors.brandForest)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.white, in: .capsule)
                    .contentShape(Capsule())
                    .contentTransition(.interpolate)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("onboarding-continue")
        }
    }

    private func complete() {
        nameFocused = false
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { metadata.ownerName = trimmed }
        BarabariInteraction.trigger(.success)
        finish()
    }
}

private struct OnboardingPage<Art: View>: View {
    let title: String
    let message: String
    @ViewBuilder let art: (Bool) -> Art

    @State private var active = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            art(active)
                .frame(height: 300)
            VStack(spacing: 12) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 16)
                Text(LocalizedStringKey(message))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .opacity(active ? 1 : 0)
                    .offset(y: active ? 0 : 16)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .foregroundStyle(.white)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) { active = true }
        }
        .onDisappear { active = false }
    }
}

/// Friends' avatars orbiting the Barabari mark.
private struct OrbitingFriends: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let friends: [(String, UInt8)] = [("Ali", 0), ("Sara", 1), ("Hamza", 2), ("Ayesha", 3), ("Bilal", 4)]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .frame(width: 250, height: 250)
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 160, height: 160)
                BarabariMark(size: 92)
                ForEach(Array(friends.enumerated()), id: \.offset) { index, friend in
                    let angle = t * 0.35 + Double(index) / Double(friends.count) * .pi * 2
                    let radius: Double = index.isMultiple(of: 2) ? 125 : 80
                    MemberAvatar(name: friend.0, seed: UUID(uuid: (friend.1, 0, 0, friend.1, 0, 0, 0, 0, 0, friend.1 &* 7, 0, 0, 0, 0, 0, 0)), size: 46)
                        .overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2) }
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                        .scaleEffect(active ? 1 : 0.2)
                        .opacity(active ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(Double(index) * 0.08), value: active)
                }
            }
        }
    }
}

/// A balance that counts up while a split bar fills in.
private struct CountingBalance: View {
    let active: Bool
    @State private var amount: Int64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("You are owed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            HeroAmount(minorUnits: amount, size: 52)
            VStack(spacing: 12) {
                splitRow("Ali", seed: 0, fraction: 0.5)
                splitRow("Sara", seed: 2, fraction: 0.3)
                splitRow("Hamza", seed: 4, fraction: 0.2)
            }
        }
        .padding(24)
        .frame(width: 310)
        .glassEffect(.clear, in: .rect(cornerRadius: 30))
        .scaleEffect(active ? 1 : 0.9)
        .opacity(active ? 1 : 0)
        .onChange(of: active) { _, isActive in
            if isActive {
                withAnimation(.spring(response: 1.4, dampingFraction: 0.9)) { amount = 1_245_000 }
            } else {
                amount = 0
            }
        }
        .onAppear {
            if active { withAnimation(.spring(response: 1.4, dampingFraction: 0.9)) { amount = 1_245_000 } }
        }
    }

    private func splitRow(_ name: String, seed: UInt8, fraction: CGFloat) -> some View {
        HStack(spacing: 10) {
            MemberAvatar(name: name, seed: UUID(uuid: (seed, 0, 0, seed &* 5, 0, 0, 0, 0, 0, seed, 0, 0, 0, 0, 0, 0)), size: 30)
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.white)
                            .frame(width: proxy.size.width * (active ? fraction : 0))
                            .animation(.spring(response: 1, dampingFraction: 0.8).delay(0.3), value: active)
                    }
                }
        }
    }
}

/// Payment methods drifting in on glass.
private struct FloatingMethods: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let methods: [(String, String, CGPoint)] = [
        ("Raast", "bolt.fill", CGPoint(x: -80, y: -100)),
        ("Easypaisa", "iphone.gen3", CGPoint(x: 70, y: -50)),
        ("JazzCash", "creditcard.fill", CGPoint(x: -60, y: 20)),
        ("Bank", "building.columns.fill", CGPoint(x: 80, y: 80)),
        ("Cash", "banknote.fill", CGPoint(x: -40, y: 120))
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Array(methods.enumerated()), id: \.offset) { index, method in
                    Label(method.0, systemImage: method.1)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .glassEffect(.clear, in: .capsule)
                        .offset(
                            x: method.2.x + sin(t * 0.8 + Double(index)) * 6,
                            y: method.2.y + cos(t * 0.7 + Double(index)) * 8
                        )
                        .offset(y: active ? 0 : 300)
                        .opacity(active ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(Double(index) * 0.09), value: active)
                }
            }
        }
    }
}
