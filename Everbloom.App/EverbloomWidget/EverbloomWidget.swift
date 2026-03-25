//
//  EverbloomWidget.swift
//  EverbloomWidget
//
//  Daily affirmation widget — small, medium, lock-screen inline & rectangular.
//  Refreshes once per day at midnight.
//

import WidgetKit
import SwiftUI

// MARK: - Affirmation Library

struct AffirmationItem {
    let text:     String
    let category: String
}

struct AffirmationLibrary {
    static let all: [AffirmationItem] = [
        AffirmationItem(text: "You are stronger than this moment.",                           category: "Strength"),
        AffirmationItem(text: "Breathe. You have survived every hard day so far.",            category: "Courage"),
        AffirmationItem(text: "Peace is available to you, right now.",                        category: "Calm"),
        AffirmationItem(text: "Your feelings are valid. You are safe.",                       category: "Grounding"),
        AffirmationItem(text: "One breath at a time is enough.",                              category: "Calm"),
        AffirmationItem(text: "Calm is always closer than it feels.",                         category: "Calm"),
        AffirmationItem(text: "You don't have to have it all figured out today.",             category: "Grace"),
        AffirmationItem(text: "Small steps forward are still progress.",                      category: "Growth"),
        AffirmationItem(text: "Healing is not linear, and that is okay.",                     category: "Grace"),
        AffirmationItem(text: "You deserve the same compassion you give others.",             category: "Self-love"),
        AffirmationItem(text: "This feeling will pass. You are not stuck.",                   category: "Hope"),
        AffirmationItem(text: "Rest is productive. Your body deserves care.",                 category: "Self-love"),
        AffirmationItem(text: "You are allowed to take up space.",                            category: "Strength"),
        AffirmationItem(text: "Anxiety is a wave — and waves always pass.",                   category: "Grounding"),
        AffirmationItem(text: "You have gotten through 100% of your hard days.",              category: "Courage"),
        AffirmationItem(text: "It is okay to ask for help. Strength knows its limits.",       category: "Grace"),
        AffirmationItem(text: "Your mind is learning. Give it patience.",                     category: "Growth"),
        AffirmationItem(text: "Right now, in this moment, you are okay.",                     category: "Grounding"),
        AffirmationItem(text: "You are worthy of good things, even on bad days.",             category: "Self-love"),
        AffirmationItem(text: "Every exhale releases what no longer serves you.",             category: "Calm"),
        AffirmationItem(text: "Your presence is enough. You don't need to perform.",          category: "Self-love"),
        AffirmationItem(text: "Fear is a visitor. It does not live here.",                    category: "Courage"),
        AffirmationItem(text: "The present moment is always manageable.",                     category: "Grounding"),
        AffirmationItem(text: "Growth happens quietly, even when you can't see it.",          category: "Growth"),
        AffirmationItem(text: "You are not your thoughts. You are the sky they move through.", category: "Wisdom"),
        AffirmationItem(text: "Gentleness is not weakness — it is wisdom.",                   category: "Wisdom"),
        AffirmationItem(text: "Even the hardest winters end in spring.",                      category: "Hope"),
        AffirmationItem(text: "You are doing the best you can. That is enough.",              category: "Grace"),
        AffirmationItem(text: "Stillness is a kind of courage too.",                          category: "Calm"),
        AffirmationItem(text: "You belong here, exactly as you are.",                         category: "Self-love"),
    ]

    /// Deterministic hourly pick — changes every hour, consistent across all widgets
    static var currentHour: AffirmationItem {
        let totalHours = Int(Date().timeIntervalSince1970) / 3600
        return all[totalHours % all.count]
    }

    /// Return the affirmation for a specific date (used to pre-generate timeline)
    static func affirmation(for date: Date) -> AffirmationItem {
        let totalHours = Int(date.timeIntervalSince1970) / 3600
        return all[totalHours % all.count]
    }
}

// MARK: - Timeline Entry

struct AffirmationEntry: TimelineEntry {
    let date:     Date
    let text:     String
    let category: String
}

// MARK: - Provider

struct AffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AffirmationEntry {
        AffirmationEntry(date: Date(),
                         text: "Peace is available to you, right now.",
                         category: "Calm")
    }

    func getSnapshot(in context: Context, completion: @escaping (AffirmationEntry) -> Void) {
        let item = AffirmationLibrary.currentHour
        completion(AffirmationEntry(date: Date(), text: item.text, category: item.category))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AffirmationEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()

        // Start from the top of the current hour
        let currentHourStart = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour], from: now)
        ) ?? now

        // Pre-generate 24 hourly entries so the widget updates without waking the app
        var entries: [AffirmationEntry] = []
        for hourOffset in 0..<24 {
            guard let entryDate = calendar.date(byAdding: .hour, value: hourOffset, to: currentHourStart) else { continue }
            let item = AffirmationLibrary.affirmation(for: entryDate)
            entries.append(AffirmationEntry(date: entryDate, text: item.text, category: item.category))
        }

        // Regenerate after 24 hours
        let refreshDate = calendar.date(byAdding: .hour, value: 24, to: currentHourStart) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

// MARK: - Colour helpers (no DesignSystem access from widget target)

private extension Color {
    static let evPurple   = Color(red: 0.55, green: 0.42, blue: 0.85)
    static let evLavender = Color(red: 0.88, green: 0.84, blue: 0.98)
    static let evText     = Color(red: 0.18, green: 0.16, blue: 0.26)
    static let evSubtext  = Color(red: 0.52, green: 0.50, blue: 0.60)
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let entry: AffirmationEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.99),
                         Color(red: 0.91, green: 0.94, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                // Branding
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.evPurple)
                    Text("EVERBLOOM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.evPurple)
                        .tracking(1.1)
                }

                Spacer()

                Text(entry.text)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.evText)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: false)

                Spacer()

                Text(entry.category.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.evPurple.opacity(0.70))
                    .tracking(0.8)
            }
            .padding(14)
        }
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let entry: AffirmationEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.99),
                         Color(red: 0.91, green: 0.96, blue: 0.97)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Decorative orb
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.evPurple.opacity(0.60),
                                     Color.evPurple.opacity(0.08)],
                            center: .center, startRadius: 4, endRadius: 44
                        ))
                        .frame(width: 82, height: 82)

                    Image(systemName: "sparkles")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.88))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.evPurple)
                        Text("HOURLY AFFIRMATION")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.evPurple)
                            .tracking(0.9)
                    }

                    Text(entry.text)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(.evText)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.80)
                        .fixedSize(horizontal: false, vertical: false)

                    Text(entry.category)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.evPurple.opacity(0.75))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.evPurple.opacity(0.12)))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

// MARK: - Lock Screen Inline (iOS 16+)

private struct LockInlineView: View {
    let entry: AffirmationEntry
    var body: some View {
        Label(entry.text, systemImage: "sparkle")
            .font(.system(size: 12, weight: .medium))
    }
}

// MARK: - Lock Screen Rectangular (iOS 16+)

private struct LockRectView: View {
    let entry: AffirmationEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .bold))
                Text("EVERBLOOM")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.9)
            }
            .foregroundColor(.secondary)

            Text(entry.text)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }
}

// MARK: - Entry View Router

struct EverbloomWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AffirmationEntry

    var body: some View {
        switch family {
        case .systemMedium:         MediumWidgetView(entry: entry)
        case .accessoryInline:      LockInlineView(entry: entry)
        case .accessoryRectangular: LockRectView(entry: entry)
        default:                    SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct EverbloomWidget: Widget {
    let kind = "EverbloomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AffirmationProvider()) { entry in
            EverbloomWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.94, green: 0.91, blue: 0.99)
                }
        }
        .configurationDisplayName("Hourly Affirmation")
        .description("A new calming quote every hour to keep you grounded.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    EverbloomWidget()
} timeline: {
    AffirmationEntry(date: .now,
                     text: "Peace is available to you, right now.",
                     category: "Calm")
    AffirmationEntry(date: .now,
                     text: "You are stronger than this moment.",
                     category: "Strength")
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Quick Actions Widget
// A small "launcher" widget with deep-link buttons for breathing, panic relief,
// and mood check-in. No shared data needed — everything is a URL link.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Simple static timeline entry

struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

// MARK: Provider (static — no data to refresh)

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        // Refresh once a day — content is static so it almost never needs to update
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [QuickActionsEntry(date: Date())], policy: .after(tomorrow)))
    }
}

// MARK: Small widget view

private struct QuickActionsSmallView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.99),
                         Color(red: 0.91, green: 0.96, blue: 0.97)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.evPurple)
                    Text("EVERBLOOM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.evPurple)
                        .tracking(1.0)
                    Spacer()
                }
                .padding(.bottom, 10)

                // Action buttons
                VStack(spacing: 8) {
                    quickLink(
                        url: "everbloom://breathe",
                        icon: "wind",
                        label: "Breathe",
                        color: Color(red: 0.55, green: 0.42, blue: 0.85)
                    )
                    quickLink(
                        url: "everbloom://panic",
                        icon: "heart.fill",
                        label: "Panic Relief",
                        color: Color(red: 0.90, green: 0.45, blue: 0.55)
                    )
                    quickLink(
                        url: "everbloom://mood",
                        icon: "face.smiling",
                        label: "Log Mood",
                        color: Color(red: 0.35, green: 0.70, blue: 0.55)
                    )
                }
            }
            .padding(14)
        }
    }

    private func quickLink(url: String, icon: String, label: String, color: Color) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.16, blue: 0.26))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(red: 0.52, green: 0.50, blue: 0.60))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.60))
            .cornerRadius(10)
        }
    }
}

// MARK: Entry view router

struct QuickActionsWidgetEntryView: View {
    let entry: QuickActionsEntry
    var body: some View {
        QuickActionsSmallView()
    }
}

// MARK: Widget definition

struct EverbloomQuickActionsWidget: Widget {
    let kind = "EverbloomQuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.94, green: 0.91, blue: 0.99)
                }
        }
        .configurationDisplayName("Quick Actions")
        .description("Instantly open Breathe, Panic Relief, or Log Mood.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    EverbloomQuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: .now)
}
