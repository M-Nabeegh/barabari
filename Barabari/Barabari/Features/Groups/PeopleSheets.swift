import SwiftUI

/// Small sheet for adding or renaming a person.
struct PersonNameSheet: View {
    let title: String
    let initialName: String
    let actionTitle: String
    let save: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 22) {
                MemberAvatar(name: name.isEmpty ? "?" : name, seed: avatarSeed, size: 76)
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: name.first)
                    .padding(.top, 20)

                TextField("Name", text: $name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isFocused)
                    .frame(minHeight: 54)
                    .padding(.horizontal, 18)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .onSubmit(submit)
                    .accessibilityIdentifier("person-name-field")

                PrimaryActionButton(actionTitle, action: submit)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .accessibilityIdentifier("person-name-save")
            }
            .padding(.horizontal, BarabariSpacing.screen)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(LocalizedStringKey(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            name = initialName
            isFocused = true
        }
    }

    private var avatarSeed: UUID {
        // Stable per name so the colour settles as you type.
        var hasher = Hasher()
        hasher.combine(name.first.map(String.init) ?? "")
        let value = UInt8(truncatingIfNeeded: abs(hasher.finalize()))
        return UUID(uuid: (value, 0, 0, value, 0, 0, 0, 0, 0, value, 0, 0, 0, 0, 0, 0))
    }

    private func submit() {
        guard !isSaving, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        Task {
            if await save(name) {
                dismiss()
            }
            isSaving = false
        }
    }
}

// MARK: - Share a balance

struct ShareBalanceSheet: View {
    let transfer: BalanceTransfer
    let groupName: String
    let fromName: String
    let toName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var renderedCard: Image?

    private var amountText: String {
        AmountFormatter.string(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode)
    }

    var message: String {
        if fromName == "You" {
            return "Hey \(toName)! I owe you \(amountText) for \(groupName). Settling up soon 🤝 — sent from Barabari"
        }
        return "Hey \(fromName)! Quick reminder: you owe \(toName == "You" ? "me" : toName) \(amountText) for \(groupName) 🙏 — sent from Barabari"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: BarabariSpacing.section) {
                card
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    Button {
                        BarabariInteraction.trigger(.selection)
                        sendOnWhatsApp()
                    } label: {
                        Label("Send on WhatsApp", systemImage: "message.fill")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color(uiColor: UIColor(hex: 0x25D366)).gradient, in: .capsule)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("share-whatsapp")

                    if let renderedCard {
                        ShareLink(
                            item: renderedCard,
                            message: Text(message),
                            preview: SharePreview("Barabari balance", image: renderedCard)
                        ) {
                            Label("Share card", systemImage: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(BarabariColors.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.pressable)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, BarabariSpacing.screen)
            .navigationTitle("Share reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationCornerRadius(36)
        .task { renderCard() }
    }

    private var card: some View {
        ShareCardView(
            fromName: fromName,
            toName: toName,
            groupName: groupName,
            transfer: transfer
        )
    }

    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(content: card.frame(width: 360).environment(\.colorScheme, .dark))
        renderer.scale = 3
        if let image = renderer.uiImage {
            renderedCard = Image(uiImage: image)
        }
    }

    private func sendOnWhatsApp() {
        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [URLQueryItem(name: "text", value: message)]
        guard let url = components.url else { return }
        openURL(url) { accepted in
            guard !accepted else { return }
            // WhatsApp isn't installed: fall back to the web composer.
            var web = URLComponents(string: "https://wa.me/")
            web?.queryItems = [URLQueryItem(name: "text", value: message)]
            if let webURL = web?.url { openURL(webURL) }
        }
    }
}

/// The card that gets shared: emerald mesh, both people, the amount.
struct ShareCardView: View {
    let fromName: String
    let toName: String
    let groupName: String
    let transfer: BalanceTransfer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Barabari", systemImage: "equal.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(groupName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: .capsule)
            }

            HStack(spacing: -10) {
                MemberAvatar(name: fromName, seed: transfer.fromUserID, size: 48)
                    .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2) }
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.22), in: .circle)
                    .zIndex(1)
                MemberAvatar(name: toName, seed: transfer.toUserID, size: 48)
                    .overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(fromName) \(fromName == "You" ? "owe" : "owes") \(toName == "You" ? "you" : toName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                HeroAmount(minorUnits: transfer.amount.minorUnits, currencyCode: transfer.amount.currencyCode, size: 44)
            }

            Text("Split fairly. Settle simply.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BarabariMeshBackground(tone: .emerald)
        }
        .clipShape(.rect(cornerRadius: 30))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: BarabariColors.brandEmerald.opacity(0.3), radius: 24, y: 12)
    }
}
