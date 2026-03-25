// CrisisResourcesView.swift
// Everbloom — Crisis Resources
//
// A dedicated, always-accessible screen listing immediate support lines.
// Design principles: calm but urgent, no clutter, one-tap calling/texting.

import SwiftUI

struct CrisisResourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didAppear = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm, grounding background — different from the usual purple
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.99),
                        Color(red: 0.95, green: 0.97, blue: 1.00),
                        Color(red: 0.97, green: 0.99, blue: 0.97),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Soft orb
                Circle()
                    .fill(Color.zenRose.opacity(0.12))
                    .frame(width: 280)
                    .blur(radius: 55)
                    .offset(x: 100, y: -160)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ── You are not alone banner ──────────────────────
                        heroCard
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: didAppear)

                        // ── Immediate crisis lines ────────────────────────
                        sectionHeader("CALL OR TEXT NOW")
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.12), value: didAppear)

                        CrisisLineCard(
                            name: "988 Suicide & Crisis Lifeline",
                            detail: "Free, confidential 24/7 support for people in distress. Call or text 988.",
                            callURL: "tel:988",
                            textURL: "sms:988",
                            textLabel: "Text 988",
                            accentColor: .zenRose,
                            icon: "heart.fill",
                            isHighlighted: true
                        )
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.17), value: didAppear)

                        CrisisLineCard(
                            name: "Crisis Text Line",
                            detail: "Text HOME to 741741. Free, 24/7 crisis counseling via text message.",
                            callURL: nil,
                            textURL: "sms:741741&body=HOME",
                            textLabel: "Text HOME to 741741",
                            accentColor: .zenPurple,
                            icon: "message.fill",
                            isHighlighted: false
                        )
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: didAppear)

                        // ── Additional support ───────────────────────────
                        sectionHeader("ADDITIONAL SUPPORT")
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.27), value: didAppear)

                        CrisisLineCard(
                            name: "SAMHSA Helpline",
                            detail: "Substance Abuse & Mental Health Services. Free, confidential referrals 24/7.",
                            callURL: "tel:18006624357",
                            textURL: nil,
                            textLabel: nil,
                            accentColor: .zenSage,
                            icon: "cross.fill",
                            isHighlighted: false
                        )
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.31), value: didAppear)

                        CrisisLineCard(
                            name: "Veterans Crisis Line",
                            detail: "For veterans, service members, and their families. Dial 988, then press 1.",
                            callURL: "tel:988",
                            textURL: "sms:838255",
                            textLabel: "Text 838255",
                            accentColor: .zenSky,
                            icon: "shield.fill",
                            isHighlighted: false
                        )
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.35), value: didAppear)

                        CrisisLineCard(
                            name: "Trevor Project (LGBTQ+)",
                            detail: "24/7 crisis support for LGBTQ+ young people. Call or text 678-678.",
                            callURL: "tel:18664887386",
                            textURL: "sms:678678",
                            textLabel: "Text START to 678-678",
                            accentColor: Color(red: 0.80, green: 0.60, blue: 1.00),
                            icon: "person.2.fill",
                            isHighlighted: false
                        )
                        .opacity(didAppear ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.39), value: didAppear)

                        // ── Emergency ────────────────────────────────────
                        sectionHeader("EMERGENCY")
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.43), value: didAppear)

                        emergencyButton
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.47), value: didAppear)

                        // ── Grounding note ───────────────────────────────
                        groundingNote
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.4).delay(0.52), value: didAppear)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Crisis Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenPurple)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                didAppear = true
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.zenRose.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "hands.and.sparkles.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.zenRose, .zenPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.monochrome)
            }

            Text("You are not alone")
                .font(ZenFont.title(22))
                .foregroundColor(.zenText)

            Text("If you are in crisis or need immediate support, please reach out to one of these free, confidential services. Help is available right now.")
                .font(ZenFont.body(15))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .shadow(color: .zenRose.opacity(0.10), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.zenRose.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Emergency Button

    private var emergencyButton: some View {
        Button {
            if let url = URL(string: "tel:911") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Emergency Services — 911")
                        .font(ZenFont.heading(15))
                        .foregroundColor(.red)
                    Text("If you or someone is in immediate danger, call 911 now.")
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.80))
                    .shadow(color: .red.opacity(0.08), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grounding Note

    private var groundingNote: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 16))
                .foregroundColor(.zenSage.opacity(0.7))

            Text("While you wait for help")
                .font(ZenFont.heading(15))
                .foregroundColor(.zenText)

            Text("Try box breathing: inhale for 4, hold for 4, exhale for 4, hold for 4. Repeat. Your breath is always available to you.")
                .font(ZenFont.body(14))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.zenSage.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.zenSage.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(1.5)
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Crisis Line Card

private struct CrisisLineCard: View {
    let name:          String
    let detail:        String
    let callURL:       String?
    let textURL:       String?
    let textLabel:     String?
    let accentColor:   Color
    let icon:          String
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                if let call = callURL {
                    CrisisActionButton(
                        label: "Call",
                        icon: "phone.fill",
                        url: call,
                        color: accentColor,
                        filled: isHighlighted
                    )
                }
                if let text = textURL, let label = textLabel {
                    CrisisActionButton(
                        label: label,
                        icon: "message.fill",
                        url: text,
                        color: accentColor,
                        filled: callURL == nil && isHighlighted
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isHighlighted
                      ? accentColor.opacity(0.10)
                      : Color.white.opacity(0.78))
                .shadow(
                    color: accentColor.opacity(isHighlighted ? 0.14 : 0.05),
                    radius: 12, x: 0, y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    accentColor.opacity(isHighlighted ? 0.35 : 0.15),
                    lineWidth: isHighlighted ? 1.5 : 1
                )
        )
    }
}

// MARK: - Crisis Action Button

private struct CrisisActionButton: View {
    let label:  String
    let icon:   String
    let url:    String
    let color:  Color
    let filled: Bool

    var body: some View {
        Button {
            guard let u = URL(string: url) else { return }
            UIApplication.shared.open(u)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(ZenFont.heading(14))
            }
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? color : color.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CrisisResourcesView()
}
