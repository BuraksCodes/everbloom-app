// MeditationLibraryView.swift
// Everbloom — Browse and launch guided meditation sessions

import SwiftUI

struct MeditationLibraryView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: MeditationCategory = .all
    @State private var selectedSession:  MeditationSession?  = nil
    @State private var appeared = false

    private var filtered: [MeditationSession] {
        MeditationLibrary.sessions(for: selectedCategory)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenGradient.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Header ────────────────────────────────────────
                        header

                        // ── Category Chips ────────────────────────────────
                        categoryStrip
                            .padding(.top, 4)
                            .padding(.bottom, 20)

                        // ── Featured "Quick Relief" Banner ────────────────
                        if selectedCategory == .all {
                            featuredBanner
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1),
                                           value: appeared)
                        }

                        // ── Session Cards ─────────────────────────────────
                        VStack(spacing: 14) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, session in
                                // Skip the featured quick-relief session when showing All
                                if selectedCategory != .all || session.durationMinutes > 3 {
                                    SessionCard(session: session) {
                                        selectedSession = session
                                    }
                                    .padding(.horizontal, 20)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 24)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.82)
                                            .delay(0.12 + Double(idx) * 0.05),
                                        value: appeared
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { appeared = true }
        .fullScreenCover(item: $selectedSession) { session in
            MeditationSessionView(session: session)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meditate")
                    .font(ZenFont.title(30))
                    .foregroundColor(.zenText)
                Text("\(MeditationLibrary.sessions.count) guided sessions")
                    .font(ZenFont.caption(14))
                    .foregroundColor(.zenSubtext)
            }
            Spacer()
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.80))
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.zenSubtext)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 18)
    }

    // MARK: - Category Strip

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MeditationCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedCategory = category
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Featured Banner (Quick 3-min session)

    private var featuredBanner: some View {
        guard let session = MeditationLibrary.sessions.first(where: { $0.durationMinutes == 3 })
                         ?? MeditationLibrary.sessions.first else {
            return AnyView(EmptyView())
        }
        return AnyView(Button { selectedSession = session } label: {
            ZStack(alignment: .leading) {
                // Gradient background
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: session.theme.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: session.theme.gradientColors[0].opacity(0.35),
                            radius: 16, x: 0, y: 6)

                // Subtle overlay pattern
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 130)
                        .offset(x: 40, y: -20)
                }

                // Content
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 58, height: 58)
                        Image(systemName: session.sfSymbol)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("QUICK RELIEF")
                                .font(ZenFont.caption(10))
                                .foregroundColor(.white.opacity(0.75))
                                .tracking(1.4)
                            Capsule()
                                .fill(Color.white.opacity(0.28))
                                .frame(height: 1)
                        }
                        Text(session.title)
                            .font(ZenFont.title(20))
                            .foregroundColor(.white)
                        Text(session.tagline)
                            .font(ZenFont.caption(13))
                            .foregroundColor(.white.opacity(0.80))
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.90))
                        Text("\(session.durationMinutes) min")
                            .font(ZenFont.caption(11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .padding(18)
            }
            .frame(height: 104)
        }
        .buttonStyle(MeditationCardButtonStyle())
        )
    }
}

// MARK: - Session Card

private struct SessionCard: View {
    let session: MeditationSession
    let action:  () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: session.theme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 58, height: 58)
                        .shadow(color: session.theme.gradientColors[0].opacity(0.30),
                                radius: 8, x: 0, y: 3)
                    Image(systemName: session.sfSymbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(ZenFont.heading(16))
                        .foregroundColor(.zenText)
                        .lineLimit(1)
                    Text(session.tagline)
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        // Duration pill
                        Label("\(session.durationMinutes) min", systemImage: "clock")
                            .font(ZenFont.caption(11))
                            .foregroundColor(session.category.tintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(session.category.tintColor.opacity(0.12))
                            .clipShape(Capsule())
                        // Category pill
                        Text(session.category.rawValue)
                            .font(ZenFont.caption(11))
                            .foregroundColor(.zenSubtext)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.zenSubtext.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "play.circle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(session.category.tintColor.opacity(0.70))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.80))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
        }
        .buttonStyle(MeditationCardButtonStyle())
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let category:   MeditationCategory
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.rawValue)
                    .font(ZenFont.body(13))
            }
            .foregroundColor(isSelected ? .white : category.tintColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected
                          ? category.tintColor
                          : category.tintColor.opacity(0.12))
                    .shadow(color: isSelected ? category.tintColor.opacity(0.30) : .clear,
                            radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button Style

private struct MeditationCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

#Preview {
    MeditationLibraryView()
}
