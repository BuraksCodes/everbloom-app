// OnboardingView.swift
// Everbloom — 5-screen first-launch walkthrough
//
// Pages:
//   0 — Welcome (Lotus)
//   1 — Tools (Tool cards)
//   2 — Bloom AI companion (Chat bubbles)
//   3 — Anxiety trigger picker  ← new interactive
//   4 — Daily reminder setup    ← new interactive

import SwiftUI

// MARK: - Page Model (standard info pages only)

private struct OnboardingPage {
    let badge:          String
    let badgeColor:     Color
    let headline:       String
    let body:           String
    let accentGradient: [Color]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        badge: "sparkles", badgeColor: .zenLavender,
        headline: "Welcome to Everbloom",
        body: "A safe, calm space for moments of anxiety, panic, and overwhelm. You don't have to face it alone.",
        accentGradient: [Color(red: 0.87, green: 0.82, blue: 0.98),
                         Color(red: 0.94, green: 0.88, blue: 1.00)]
    ),
    OnboardingPage(
        badge: "leaf.fill", badgeColor: .zenSage,
        headline: "Tools that actually work",
        body: "Breathing exercises, grounding techniques, a mindfulness journal, and calming sounds — every one backed by research.",
        accentGradient: [Color(red: 0.82, green: 0.95, blue: 0.88),
                         Color(red: 0.88, green: 0.98, blue: 0.93)]
    ),
    OnboardingPage(
        badge: "heart.fill", badgeColor: .zenRose,
        headline: "Meet Bloom",
        body: "Your compassionate AI companion. Talk through what you're feeling, learn coping techniques, and feel heard — any time, any day.",
        accentGradient: [Color(red: 1.00, green: 0.90, blue: 0.86),
                         Color(red: 1.00, green: 0.95, blue: 0.92)]
    ),
    // Pages 3 & 4 use custom cards but share the same accentGradient system
    OnboardingPage(
        badge: "bolt.fill", badgeColor: .zenPeach,
        headline: "", body: "",
        accentGradient: [Color(red: 1.00, green: 0.94, blue: 0.88),
                         Color(red: 1.00, green: 0.97, blue: 0.92)]
    ),
    OnboardingPage(
        badge: "bell.fill", badgeColor: .zenSky,
        headline: "", body: "",
        accentGradient: [Color(red: 0.88, green: 0.95, blue: 1.00),
                         Color(red: 0.92, green: 0.97, blue: 1.00)]
    ),
]

// MARK: - Anxiety triggers data

private let anxietyTriggers: [String] = [
    "Work", "Relationships", "Health", "Social",
    "Sleep", "Money", "Perfectionism", "Change",
    "Future", "Conflict",
]

// MARK: - Floating Wrapper

private struct FloatingView<Content: View>: View {
    @State private var floating = false
    let amplitude:  CGFloat
    let duration:   Double
    let startDelay: Double
    let content:    Content

    init(amplitude: CGFloat = 4, duration: Double = 2.6, startDelay: Double = 0,
         @ViewBuilder content: () -> Content) {
        self.amplitude  = amplitude
        self.duration   = duration
        self.startDelay = startDelay
        self.content    = content()
    }

    var body: some View {
        content
            .offset(y: floating ? -amplitude : amplitude)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        floating = true
                    }
                }
            }
    }
}

// MARK: - Page 1: Lotus Mandala

private struct LotusIllustration: View {
    @State private var appeared = false
    @State private var pulse    = false

    private let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (-108, -74, 7.0, 0.72),
        (  98, -90, 5.5, 0.80),
        ( -86,  80, 6.5, 0.76),
        ( 102,  66, 5.0, 0.85),
        (   8,-118, 6.0, 0.68),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0.74, green: 0.60, blue: 0.98).opacity(0.42), .clear],
                    center: .center, startRadius: 30, endRadius: 130
                ))
                .frame(width: 260, height: 260)
                .scaleEffect(pulse ? 1.12 : 0.94)

            ForEach(0..<8, id: \.self) { i in
                petal(i: i, total: 8, w: 30, h: 66, dist: 74,
                      top: Color(red: 0.67, green: 0.51, blue: 0.96),
                      bot: Color(red: 0.83, green: 0.70, blue: 0.99), baseDelay: 0.00)
            }
            ForEach(0..<6, id: \.self) { i in
                petal(i: i, total: 6, w: 24, h: 50, dist: 44,
                      top: Color(red: 0.71, green: 0.56, blue: 0.97),
                      bot: Color(red: 0.87, green: 0.75, blue: 0.99), baseDelay: 0.24)
            }
            ForEach(0..<5, id: \.self) { i in
                petal(i: i, total: 5, w: 18, h: 36, dist: 24,
                      top: Color(red: 0.77, green: 0.62, blue: 0.98),
                      bot: Color(red: 0.91, green: 0.80, blue: 1.00), baseDelay: 0.46)
            }

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.white, Color(red: 0.90, green: 0.82, blue: 1.00)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(red: 0.67, green: 0.51, blue: 0.96).opacity(0.45),
                            radius: 10, x: 0, y: 2)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.67, green: 0.51, blue: 0.96).opacity(0.70))
            }
            .scaleEffect(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.65), value: appeared)

            ForEach(sparkles.indices, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.67, green: 0.51, blue: 0.96).opacity(0.52))
                    .frame(width: sparkles[i].size, height: sparkles[i].size)
                    .offset(x: sparkles[i].x, y: sparkles[i].y)
                    .scaleEffect(appeared ? 1 : 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6).delay(sparkles[i].delay),
                        value: appeared
                    )
            }
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    @ViewBuilder
    private func petal(i: Int, total: Int, w: CGFloat, h: CGFloat, dist: CGFloat,
                       top: Color, bot: Color, baseDelay: Double) -> some View {
        let angle = Angle(degrees: Double(i) * (360.0 / Double(total)) - 90)
        let tx    = CGFloat(cos(angle.radians)) * dist
        let ty    = CGFloat(sin(angle.radians)) * dist
        let delay = baseDelay + Double(i) * 0.050

        Capsule()
            .fill(LinearGradient(colors: [top, bot], startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
            .rotationEffect(angle + .degrees(90))
            .offset(x: appeared ? tx : 0, y: appeared ? ty : 0)
            .opacity(appeared ? 0.80 : 0)
            .animation(.spring(response: 0.58, dampingFraction: 0.72).delay(delay), value: appeared)
    }
}

// MARK: - Page 2: Tool Cards

private struct ToolsIllustration: View {
    @State private var appeared = false

    private let tools: [(icon: String, label: String, tint: Color, bg: [Color])] = [
        ("wind",               "Breathe",
         Color(red: 0.38, green: 0.66, blue: 0.92),
         [Color(red: 0.72, green: 0.88, blue: 1.00), Color(red: 0.86, green: 0.96, blue: 1.00)]),
        ("book.fill",          "Journal",
         Color(red: 0.36, green: 0.74, blue: 0.54),
         [Color(red: 0.74, green: 0.94, blue: 0.80), Color(red: 0.86, green: 0.98, blue: 0.88)]),
        ("speaker.wave.2.fill","Sounds",
         Color(red: 0.60, green: 0.48, blue: 0.92),
         [Color(red: 0.84, green: 0.78, blue: 1.00), Color(red: 0.92, green: 0.87, blue: 1.00)]),
        ("hand.raised.fill",   "Ground",
         Color(red: 0.86, green: 0.54, blue: 0.36),
         [Color(red: 1.00, green: 0.86, blue: 0.76), Color(red: 1.00, green: 0.93, blue: 0.86)]),
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                toolCard(idx: 0, delay: 0.04)
                toolCard(idx: 1, delay: 0.14)
            }
            HStack(spacing: 16) {
                toolCard(idx: 2, delay: 0.24)
                toolCard(idx: 3, delay: 0.34)
            }
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func toolCard(idx: Int, delay: Double) -> some View {
        let t = tools[idx]
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: t.bg, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: t.tint.opacity(0.26), radius: 8, x: 0, y: 3)
                Image(systemName: t.icon)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundColor(t.tint)
            }
            Text(t.label)
                .font(ZenFont.caption(13))
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.28, green: 0.32, blue: 0.40))
        }
        .frame(width: 114, height: 114)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.90))
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 5)
        )
        .scaleEffect(appeared ? 1.0 : 0.55)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.52, dampingFraction: 0.72).delay(delay), value: appeared)
    }
}

// MARK: - Page 3: Bloom Chat

private struct BloomIllustration: View {
    @State private var appeared = false

    private let hearts: [(x: CGFloat, y: CGFloat, size: CGFloat, color: Color, delay: Double)] = [
        (-92,  24, 14, Color(red: 0.95, green: 0.58, blue: 0.58), 0.64),
        ( 88, -26, 11, Color(red: 0.92, green: 0.68, blue: 0.62), 0.78),
        (-68, -90,  9, Color(red: 0.85, green: 0.54, blue: 0.76), 0.54),
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.00, green: 0.84, blue: 0.80).opacity(0.60), .clear],
                    center: .center, startRadius: 12, endRadius: 118
                ))
                .frame(width: 236, height: 236)

            FloatingView(amplitude: 4, duration: 2.5, startDelay: 0.75) {
                chatBubble("I feel overwhelmed...", isUser: true)
            }
            .offset(x: -52, y: -84)
            .scaleEffect(appeared ? 1 : 0.35, anchor: .bottomLeading)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.32), value: appeared)

            FloatingView(amplitude: 5, duration: 2.9, startDelay: 0.95) {
                chatBubble("You've got this. Let's breathe.", isUser: false)
            }
            .offset(x: 46, y: 74)
            .scaleEffect(appeared ? 1 : 0.35, anchor: .topTrailing)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.58, dampingFraction: 0.72).delay(0.52), value: appeared)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(red: 1.00, green: 0.78, blue: 0.72),
                                 Color(red: 0.90, green: 0.68, blue: 0.90)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.58, dampingFraction: 0.70).delay(0.06), value: appeared)

            Image("BloomAvatar")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.60, dampingFraction: 0.72).delay(0.04), value: appeared)

            ForEach(hearts.indices, id: \.self) { i in
                let h = hearts[i]
                Image(systemName: "heart.fill")
                    .font(.system(size: h.size))
                    .foregroundColor(h.color.opacity(0.76))
                    .offset(x: h.x, y: h.y)
                    .scaleEffect(appeared ? 1 : 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(h.delay), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private func chatBubble(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isUser ? Color(red: 0.30, green: 0.30, blue: 0.42) : .white)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: 138)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isUser ? Color.white : Color(red: 0.68, green: 0.50, blue: 0.90))
                    .shadow(color: Color.black.opacity(0.09), radius: 7, x: 0, y: 2)
            )
    }
}

// MARK: - Page 4: Trigger Illustration

private struct TriggerIllustration: View {
    let selectedCount: Int
    @State private var appeared = false

    private let orbs: [(x: CGFloat, y: CGFloat, color: Color, size: CGFloat, delay: Double)] = [
        (-88, -44, .zenPeach,  50, 0.08),
        ( 82, -72, .zenPurple, 42, 0.16),
        (-68,  62, .zenSage,   46, 0.24),
        ( 86,  48, .zenSky,    40, 0.12),
        (  0, -96, .zenRose,   36, 0.20),
    ]

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [Color.zenPeach.opacity(0.30), .clear],
                    center: .center, startRadius: 10, endRadius: 120
                ))
                .frame(width: 240, height: 240)

            // Floating orbs
            ForEach(orbs.indices, id: \.self) { i in
                let o = orbs[i]
                Circle()
                    .fill(o.color.opacity(0.28))
                    .frame(width: o.size, height: o.size)
                    .offset(x: o.x, y: o.y)
                    .scaleEffect(appeared ? 1.0 : 0.2)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.70).delay(o.delay), value: appeared)
            }

            // Central icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.00, green: 0.90, blue: 0.78),
                                 Color(red: 1.00, green: 0.96, blue: 0.88)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 84, height: 84)
                    .shadow(color: .zenPeach.opacity(0.30), radius: 16, x: 0, y: 5)

                Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.zenPeach,
                                     Color(red: 0.88, green: 0.52, blue: 0.36)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: selectedCount)
            }
            .scaleEffect(appeared ? 1 : 0.35)
            .animation(.spring(response: 0.58, dampingFraction: 0.68).delay(0.04), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Page 5: Notification Illustration

private struct NotificationIllustration: View {
    @State private var appeared = false
    @State private var ring     = false

    var body: some View {
        ZStack {
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [Color.zenSky.opacity(0.32), .clear],
                    center: .center, startRadius: 10, endRadius: 120
                ))
                .frame(width: 240, height: 240)

            // Ripple rings
            ForEach([0, 1, 2], id: \.self) { i in
                Circle()
                    .stroke(Color.zenSky.opacity(0.20 - Double(i) * 0.05), lineWidth: 1.5)
                    .frame(width: CGFloat(96 + i * 30), height: CGFloat(96 + i * 30))
                    .scaleEffect(ring ? 1.14 : 1.0)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.45),
                        value: ring
                    )
            }

            // Bell button
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.82, green: 0.93, blue: 1.00),
                                 Color(red: 0.90, green: 0.97, blue: 1.00)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)
                    .shadow(color: .zenSky.opacity(0.28), radius: 16, x: 0, y: 5)

                Image(systemName: "bell.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.zenSky, Color(red: 0.28, green: 0.58, blue: 0.90)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(ring ? -14 : 14))
                    .animation(
                        .easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(0.4),
                        value: ring
                    )
            }
            .scaleEffect(appeared ? 1 : 0.35)
            .animation(.spring(response: 0.58, dampingFraction: 0.68).delay(0.04), value: appeared)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ring = true }
        }
    }
}

// MARK: - Trigger Chip

private struct TriggerChip: View {
    let label:      String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(label)
                    .font(ZenFont.body(14))
            }
            .foregroundColor(isSelected ? .white : .zenText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected
                          ? Color.zenPeach
                          : Color.white.opacity(0.80))
                    .shadow(color: isSelected
                            ? Color.zenPeach.opacity(0.30)
                            : Color.black.opacity(0.06),
                            radius: 6, x: 0, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected
                            ? Color.clear
                            : Color.zenPeach.opacity(0.30),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

/// MARK: - OnboardingView

struct OnboardingView: View {

    // Completion flag
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false

    // Trigger picker persistence
    @AppStorage("anxietyTriggers")       private var triggersRaw:  String = ""

    // Notification persistence
    @AppStorage("moodReminderEnabled")   private var moodEnabled:  Bool   = false
    @AppStorage("moodReminderHour")      private var moodHour:     Int    = 9
    @AppStorage("moodReminderMinute")    private var moodMinute:   Int    = 0

    // Navigation
    @State private var currentPage         = 0

    // Animation states
    @State private var illustrationScale:   CGFloat = 0.85
    @State private var illustrationOpacity: Double  = 0
    @State private var contentOffset:       CGFloat = 30
    @State private var contentOpacity:      Double  = 0

    // Page 4 — trigger picker
    @State private var selectedTriggers: Set<String> = []

    // Page 5 — notification
    @State private var reminderTime:     Date    = {
        var c    = DateComponents(); c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var reminderEnabled    = false
    @State private var reminderError      = false

    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                colors: pages[currentPage].accentGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            // Ambient blobs
            ambientBlobs

            VStack(spacing: 0) {
                // Skip button row
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                hasCompleted = true
                            }
                        }
                        .font(ZenFont.body(15))
                        .foregroundColor(.zenSubtext)
                        .padding(.trailing, 24)
                        .padding(.top, 16)
                    }
                }
                .frame(height: 52)

                // Illustration
                illustrationArea
                    .scaleEffect(illustrationScale)
                    .opacity(illustrationOpacity)

                // Content card (varies by page)
                contentCardView
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Ambient Blobs

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 280)
                .blur(radius: 52)
                .offset(x: -100, y: -220)
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 220)
                .blur(radius: 44)
                .offset(x: 120, y: 260)
        }
        .ignoresSafeArea()
    }

    // MARK: - Illustration Area

    private var illustrationArea: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 288, height: 288)
                .blur(radius: 20)

            Group {
                switch currentPage {
                case 0: LotusIllustration()
                case 1: ToolsIllustration()
                case 2: BloomIllustration()
                case 3: TriggerIllustration(selectedCount: selectedTriggers.count)
                default: NotificationIllustration()
                }
            }
            .id(currentPage)
            .frame(width: 280, height: 280)
        }
        .frame(maxHeight: currentPage >= 3 ? 240 : 310)
        .padding(.top, 8)
    }

    // MARK: - Content Card (routed by page)

    @ViewBuilder
    private var contentCardView: some View {
        switch currentPage {
        case 3:  triggerPickerCard
        case 4:  notificationCard
        default: standardContentCard
        }
    }

    // MARK: - Standard Content Card (pages 0–2)

    private var standardContentCard: some View {
        VStack(spacing: 0) {
            // Progress pills
            progressPills
                .padding(.top, 28)
                .padding(.bottom, 20)

            // Badge chip
            HStack(spacing: 7) {
                Image(systemName: pages[currentPage].badge)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(pages[currentPage].badgeColor)
                Text(badgeLabel)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                    .tracking(1.2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(pages[currentPage].badgeColor.opacity(0.22))
            .clipShape(Capsule())
            .padding(.bottom, 14)
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Headline
            Text(pages[currentPage].headline)
                .font(ZenFont.title(26))
                .foregroundColor(.zenText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Body
            Text(pages[currentPage].body)
                .font(ZenFont.body(16))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Action button
            actionButton
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: .zenDusk.opacity(0.08), radius: 24, x: 0, y: -6)
        )
    }

    // MARK: - Trigger Picker Card (page 3)

    private var triggerPickerCard: some View {
        VStack(spacing: 0) {
            progressPills
                .padding(.top, 24)
                .padding(.bottom, 18)

            // Header
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.zenPeach)
                    Text("PERSONALISE")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext)
                        .tracking(1.2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.zenPeach.opacity(0.18))
                .clipShape(Capsule())

                Text("What triggers your anxiety?")
                    .font(ZenFont.title(22))
                    .foregroundColor(.zenText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Select all that apply. We'll personalise your experience.")
                    .font(ZenFont.body(14))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 20)

            // Chip grid
            let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(anxietyTriggers, id: \.self) { trigger in
                    TriggerChip(
                        label: trigger,
                        isSelected: selectedTriggers.contains(trigger)
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedTriggers.contains(trigger) {
                            selectedTriggers.remove(trigger)
                        } else {
                            selectedTriggers.insert(trigger)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Continue button
            Button {
                // Save selections and advance
                triggersRaw = selectedTriggers.joined(separator: ",")
                advancePage()
            } label: {
                HStack(spacing: 10) {
                    Text(selectedTriggers.isEmpty ? "Skip for now" : "Continue")
                        .font(ZenFont.heading(17))
                    if !selectedTriggers.isEmpty {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [.zenPeach, Color(red: 0.88, green: 0.52, blue: 0.36)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .zenPeach.opacity(0.32), radius: 12, x: 0, y: 5)
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: .zenDusk.opacity(0.08), radius: 24, x: 0, y: -6)
        )
    }

    // MARK: - Notification Card (page 4)

    private var notificationCard: some View {
        VStack(spacing: 0) {
            progressPills
                .padding(.top, 24)
                .padding(.bottom, 18)

            // Header
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.zenSky)
                    Text("REMINDERS")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext)
                        .tracking(1.2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.zenSky.opacity(0.18))
                .clipShape(Capsule())

                Text("Set a daily check-in")
                    .font(ZenFont.title(22))
                    .foregroundColor(.zenText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("A gentle nudge to log your mood. Takes just a second.")
                    .font(ZenFont.body(14))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 16)

            // Time picker
            DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            // Status indicator
            if reminderEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.zenSage)
                        .font(.system(size: 14))
                    Text("Daily reminder set!")
                        .font(ZenFont.body(14))
                        .foregroundColor(.zenSage)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if reminderError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.zenPeach)
                        .font(.system(size: 14))
                    Text("Enable in Settings → Notifications")
                        .font(ZenFont.body(13))
                        .foregroundColor(.zenPeach)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Enable button
            if !reminderEnabled {
                Button {
                    Task {
                        let granted = await NotificationManager.shared.requestPermission()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            if granted {
                                let comps  = Calendar.current.dateComponents([.hour, .minute],
                                                                              from: reminderTime)
                                moodHour   = comps.hour   ?? 9
                                moodMinute = comps.minute ?? 0
                                NotificationManager.shared.scheduleMoodReminder(
                                    hour: moodHour, minute: moodMinute)
                                moodEnabled    = true
                                reminderEnabled = true
                                reminderError   = false
                            } else {
                                reminderError   = true
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Enable Daily Reminder")
                            .font(ZenFont.heading(17))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [.zenSky, Color(red: 0.28, green: 0.58, blue: 0.90)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .zenSky.opacity(0.32), radius: 12, x: 0, y: 5)
                }
                .buttonStyle(OnboardingButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }

            // Get Started
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    hasCompleted = true
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Get Started")
                        .font(ZenFont.heading(17))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(reminderEnabled ? .zenPurple : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    Group {
                        if reminderEnabled {
                            Color.zenPurple.opacity(0.12)
                        } else {
                            LinearGradient(
                                colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: reminderEnabled ? .clear : .zenPurple.opacity(0.28), radius: 12, x: 0, y: 5)
                .overlay(
                    Group {
                        if reminderEnabled {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.zenPurple.opacity(0.30), lineWidth: 1.5)
                        }
                    }
                )
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: .zenDusk.opacity(0.08), radius: 24, x: 0, y: -6)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: reminderEnabled)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: reminderError)
    }

    // MARK: - Progress Pills

    private var progressPills: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage
                          ? Color.zenPurple
                          : Color.zenPurple.opacity(0.22))
                    .frame(width: i == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
            }
        }
    }

    // MARK: - Standard Action Button (pages 0–2)

    private var actionButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                advancePage()
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    hasCompleted = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                    .font(ZenFont.heading(17))
                Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .zenPurple.opacity(0.32), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(OnboardingButtonStyle())
    }

    // MARK: - Helpers

    private var badgeLabel: String {
        switch currentPage {
        case 0: return "WELCOME"
        case 1: return "YOUR TOOLS"
        default: return "AI COMPANION"
        }
    }

    private func advancePage() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.18)) {
            illustrationScale   = 0.92
            illustrationOpacity = 0
            contentOpacity      = 0
            contentOffset       = -16
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            currentPage  += 1
            contentOffset = 30
            animateIn()
        }
    }

    private func animateIn() {
        illustrationScale   = 0.85
        illustrationOpacity = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
            illustrationScale   = 1.0
            illustrationOpacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.15)) {
            contentOffset  = 0
            contentOpacity = 1.0
        }
    }
}

// MARK: - Button Style

private struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
}
