// DesignSystem.swift
// Everbloom — Anxiety & Panic Support App
// Japanese Zen inspired pastel design system

import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary pastels
    static let zenLavender    = Color(red: 0.85, green: 0.80, blue: 0.95)   // #D9CCF2
    static let zenPeach       = Color(red: 0.98, green: 0.87, blue: 0.82)   // #FADDD1
    static let zenSage        = Color(red: 0.80, green: 0.90, blue: 0.84)   // #CCE6D6
    static let zenSky         = Color(red: 0.80, green: 0.90, blue: 0.97)   // #CCE5F7
    static let zenRose        = Color(red: 0.97, green: 0.82, blue: 0.86)   // #F7D1DB
    static let zenCream       = Color(red: 0.98, green: 0.96, blue: 0.93)   // #FAF5ED

    // Accent / deeper tones
    static let zenPurple      = Color(red: 0.55, green: 0.40, blue: 0.75)   // #8C66BF
    static let zenMoss        = Color(red: 0.40, green: 0.60, blue: 0.48)   // #66997A
    static let zenDusk        = Color(red: 0.35, green: 0.30, blue: 0.50)   // #594D80

    // Text
    static let zenText        = Color(red: 0.22, green: 0.20, blue: 0.28)   // #383248
    static let zenSubtext     = Color(red: 0.55, green: 0.52, blue: 0.60)   // #8C8599

    // Background gradient stops
    static let bgTop          = Color(red: 0.96, green: 0.93, blue: 0.99)   // #F5EDF9
    static let bgBottom       = Color(red: 0.93, green: 0.96, blue: 0.99)   // #EDF3FC
}

// MARK: - Gradient Presets

struct ZenGradient {
    static let background = LinearGradient(
        colors: [.bgTop, .bgBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panic = LinearGradient(
        colors: [Color(red: 0.95, green: 0.82, blue: 0.88), Color(red: 0.85, green: 0.76, blue: 0.95)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let breathe = LinearGradient(
        colors: [.zenSky, .zenLavender],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sounds = LinearGradient(
        colors: [.zenSage, .zenSky],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let journal = LinearGradient(
        colors: [.zenPeach, .zenRose],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

struct ZenFont {
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func mono(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }
}

// MARK: - Card Modifier

struct ZenCard: ViewModifier {
    var color: Color = .white.opacity(0.75)
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
                    .shadow(color: .zenDusk.opacity(0.08), radius: 12, x: 0, y: 4)
            )
    }
}

extension View {
    func zenCard(color: Color = .white.opacity(0.75), cornerRadius: CGFloat = 20) -> some View {
        modifier(ZenCard(color: color, cornerRadius: cornerRadius))
    }

    /// Staggered fade-up entrance animation used across all screens
    func animatedEntry(delay: Double = 0, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.82).delay(delay),
                value: appeared
            )
    }
}

// MARK: - Tab Item Labels

enum AppTab: String, CaseIterable {
    case home     = "Home"
    case breathe  = "Breathe"
    case meditate = "Meditate"
    case journal  = "Journal"
    case chat     = "Bloom"
    case profile  = "Profile"

    var icon: String {
        switch self {
        case .home:     return "heart.fill"
        case .breathe:  return "wind"
        case .meditate: return "figure.mind.and.body"
        case .journal:  return "book.closed.fill"
        case .chat:     return "bubble.left.and.bubble.right.fill"
        case .profile:  return "person.fill"
        }
    }
}
