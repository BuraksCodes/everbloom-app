// PaywallView.swift
// Everbloom — Premium subscription paywall

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: String = "com.everbloom.premium.annual"
    @State private var appeared = false

    private let features: [(icon: String, color: Color, title: String, subtitle: String)] = [
        ("bubble.left.and.bubble.right.fill", Color(red: 0.55, green: 0.40, blue: 0.75),
         "Unlimited Bloom Chats",       "No daily message limits — always here for you"),
        ("waveform.path.ecg.rectangle",        Color(red: 0.40, green: 0.60, blue: 0.75),
         "All 10 Breathing Techniques", "4 advanced techniques — Pursed Lip, Resonant, Triangle & more"),
        ("headphones",                          Color(red: 0.40, green: 0.60, blue: 0.48),
         "Full Sound Library",          "Rain, ocean, forest & more ambient sounds"),
        ("book.closed.fill",                    Color(red: 0.80, green: 0.55, blue: 0.30),
         "Unlimited Journal",           "Write as much as you need, always"),
        ("person.fill.checkmark",               Color(red: 0.65, green: 0.35, blue: 0.65),
         "Therapist Finder",            "Search therapists worldwide with ratings & reviews"),
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.20),
                    Color(red: 0.18, green: 0.13, blue: 0.30),
                    Color(red: 0.10, green: 0.08, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient blobs
            ZStack {
                Circle()
                    .fill(Color(red: 0.55, green: 0.40, blue: 0.75).opacity(0.18))
                    .frame(width: 320).blur(radius: 70)
                    .offset(x: -120, y: -300)
                Circle()
                    .fill(Color(red: 0.40, green: 0.55, blue: 0.85).opacity(0.14))
                    .frame(width: 280).blur(radius: 60)
                    .offset(x: 130, y: 100)
                Circle()
                    .fill(Color(red: 0.75, green: 0.45, blue: 0.65).opacity(0.12))
                    .frame(width: 240).blur(radius: 55)
                    .offset(x: 80, y: 400)
            }
            .ignoresSafeArea()

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero ──
                    heroSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.05), value: appeared)

                    // ── Feature list ──
                    featureList
                        .padding(.top, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.15), value: appeared)

                    // ── Plan picker ──
                    planPicker
                        .padding(.top, 28)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.25), value: appeared)

                    // ── CTA ──
                    ctaSection
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.32), value: appeared)

                    // ── Footer links ──
                    footerLinks
                        .padding(.top, 18)
                        .padding(.bottom, 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeIn(duration: 0.4).delay(0.4), value: appeared)
                }
                .padding(.horizontal, 22)
            }

            // Close button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.trailing, 22)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            // Crown + glow
            ZStack {
                Circle()
                    .fill(Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.18))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                Image(systemName: "crown.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.88, blue: 0.45),
                                     Color(red: 0.85, green: 0.68, blue: 0.22)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 80)

            Text("Everbloom Premium")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Your full support system,\nunlocked.")
                .font(ZenFont.body(17))
                .foregroundColor(.white.opacity(0.70))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                FeatureRow(
                    icon: feature.icon,
                    iconColor: feature.color,
                    title: feature.title,
                    subtitle: feature.subtitle
                )
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.80)
                        .delay(0.15 + Double(index) * 0.06),
                    value: appeared
                )
            }
        }
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(subscriptionManager.products) { product in
                PlanCard(
                    product: product,
                    isSelected: selectedProduct == product.id
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedProduct = product.id
                    }
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            // ── Error / status message ──
            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(ZenFont.caption(13))
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                Task { await subscriptionManager.purchase(selectedProduct) }
            } label: {
                ZStack {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(ctaTitle)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.14, green: 0.10, blue: 0.22))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.88, blue: 0.45),
                                 Color(red: 0.90, green: 0.72, blue: 0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .disabled(subscriptionManager.isPurchasing)

            Text("Cancel anytime. No commitment.")
                .font(ZenFont.caption(12))
                .foregroundColor(.white.opacity(0.45))
        }
        .animation(.easeInOut(duration: 0.3), value: subscriptionManager.errorMessage)
    }

    private var ctaTitle: String {
        if selectedProduct == "com.everbloom.premium.annual" {
            return "Start Free Trial — $49.99/yr"
        } else {
            return "Start Free Trial — $7.99/mo"
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(ZenFont.caption(12))
                    .foregroundColor(.white.opacity(0.40))
            }

            Text("·")
                .foregroundColor(.white.opacity(0.25))

            Button {
                if let url = URL(string: "https://burakscodes.github.io/everbloom-app/privacy-policy.html") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Privacy Policy")
                    .font(ZenFont.caption(12))
                    .foregroundColor(.white.opacity(0.40))
            }

            Text("·")
                .foregroundColor(.white.opacity(0.25))

            Button {
                if let url = URL(string: "https://everbloom.app/terms") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Terms")
                    .font(ZenFont.caption(12))
                    .foregroundColor(.white.opacity(0.40))
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.20))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZenFont.heading(15))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.28))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(isSelected
                                ? Color(red: 0.85, green: 0.72, blue: 0.28)
                                : Color.white.opacity(0.25),
                                lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color(red: 0.85, green: 0.72, blue: 0.28))
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.title)
                            .font(ZenFont.heading(16))
                            .foregroundColor(.white)
                        if product.isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.14, green: 0.10, blue: 0.22))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.85, green: 0.72, blue: 0.28))
                                .clipShape(Capsule())
                        }
                    }
                    if let savings = product.savings {
                        Text(savings)
                            .font(ZenFont.caption(12))
                            .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.28))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.price)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(product.period)
                        .font(ZenFont.caption(11))
                        .foregroundColor(.white.opacity(0.50))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected
                          ? Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.16)
                          : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected
                                    ? Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.60)
                                    : Color.white.opacity(0.12),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
