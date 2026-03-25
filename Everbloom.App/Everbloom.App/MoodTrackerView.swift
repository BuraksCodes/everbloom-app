// MoodTrackerView.swift
// Everbloom — Mood trend chart + check-in history
//
// Features:
//  • Swift Charts line chart with smooth Catmull-Rom interpolation
//  • Time range picker: 7 / 14 / 30 days
//  • Area gradient fill under the line
//  • Emoji Y-axis labels matching the 5 mood levels
//  • Stats row: average mood · best day · check-in streak
//  • Scrollable list of past check-ins with mood badge + optional note

import SwiftUI
import Charts

struct MoodTrackerView: View {
    @EnvironmentObject var moodStore: MoodStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRange: TimeRange = .week
    @State private var didAppear = false

    // MARK: - Time Range

    enum TimeRange: String, CaseIterable {
        case week      = "7 Days"
        case twoWeeks  = "14 Days"
        case month     = "30 Days"

        var days: Int {
            switch self { case .week: return 7; case .twoWeeks: return 14; case .month: return 30 }
        }
    }

    // MARK: - Chart Data

    /// One data point per day that has a check-in within the selected range.
    /// Days without a check-in produce a gap in the chart (intentional).
    private var chartData: [ChartPoint] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let all   = moodStore.recentEntries(days: selectedRange.days)

        return (0..<selectedRange.days).compactMap { offset -> ChartPoint? in
            guard let day = cal.date(
                byAdding: .day,
                value: -(selectedRange.days - 1 - offset),
                to: today
            ) else { return nil }

            guard let match = all.first(where: { cal.isDate($0.date, inSameDayAs: day) })
            else { return nil }   // no check-in → gap

            return ChartPoint(date: day, score: Double(match.mood.score), mood: match.mood)
        }
    }

    // MARK: - Summary Stats

    private var averageMood: JournalEntry.Mood? {
        guard !chartData.isEmpty else { return nil }
        let avg = chartData.map(\.score).reduce(0, +) / Double(chartData.count)
        return .from(score: Int(avg.rounded()))
    }

    private var bestDayLabel: String {
        guard let best = chartData.max(by: { $0.score < $1.score }) else { return "—" }
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return fmt.string(from: best.date)
    }

    private var checkInStreak: Int {
        let cal   = Calendar.current
        var count = 0
        for i in 0..<90 {
            guard let day = cal.date(byAdding: .day, value: -i, to: Date()) else { break }
            if moodStore.entries.contains(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                count += 1
            } else if i > 0 {
                break
            }
        }
        return count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ZenGradient.background.ignoresSafeArea()
                Circle()
                    .fill(Color.zenLavender.opacity(0.20))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -90, y: -180)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            ForEach(TimeRange.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)
                        .animatedEntry(delay: 0.05, appeared: didAppear)

                        // Chart
                        chartCard
                            .animatedEntry(delay: 0.12, appeared: didAppear)

                        // Stats row
                        statsRow
                            .animatedEntry(delay: 0.20, appeared: didAppear)

                        // Recent check-ins list
                        recentList
                            .animatedEntry(delay: 0.28, appeared: didAppear)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Mood Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenPurple)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                didAppear = true
            }
        }
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MOOD TREND")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.zenSubtext)
                    .tracking(1.5)
                Spacer()
                if !chartData.isEmpty {
                    Text("\(chartData.count) of \(selectedRange.days) days logged")
                        .font(ZenFont.caption(11))
                        .foregroundColor(.zenSubtext.opacity(0.65))
                }
            }

            if chartData.isEmpty {
                emptyState
            } else {
                Chart(chartData) { point in
                    // Gradient area fill
                    AreaMark(
                        x: .value("Day",   point.date,  unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.zenPurple.opacity(0.22),
                                Color.zenLavender.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Line
                    LineMark(
                        x: .value("Day",   point.date,  unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.zenPurple, Color.zenSage],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    // Data point dots
                    PointMark(
                        x: .value("Day",   point.date,  unit: .day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(point.mood.color)
                    .symbolSize(80)
                }
                .chartYScale(domain: 0.5...5.5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine(
                            stroke: StrokeStyle(lineWidth: 0.5, dash: [4])
                        )
                        .foregroundStyle(Color.zenSubtext.opacity(0.18))

                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Image(JournalEntry.Mood.from(score: v).imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(
                        values: .stride(by: .day, count: selectedRange == .month ? 7 : 1)
                    ) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.zenSubtext)
                    }
                }
                .frame(height: 185)
                .animation(.easeInOut(duration: 0.3), value: selectedRange)
            }
        }
        .padding(18)
        .zenCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.zenLavender.opacity(0.45))
            Text("No check-ins yet")
                .font(ZenFont.heading(16))
                .foregroundColor(.zenText.opacity(0.65))
            Text("Log your mood each day to see your trend here")
                .font(ZenFont.caption(13))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            MoodStatPill(
                topText:    averageMood == nil ? "—" : nil,
                imageName:  averageMood?.imageName,
                label:      "Average",
                color:      averageMood?.color ?? .zenLavender
            )
            MoodStatPill(
                topText:    bestDayLabel,
                imageName:  nil,
                label:      "Best Day",
                color:      .zenSage
            )
            MoodStatPill(
                topText:    "\(checkInStreak)",
                imageName:  nil,
                label:      "Day Streak",
                color:      .zenPeach
            )
        }
    }

    // MARK: - Recent List

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECENT CHECK-INS")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(1.5)

            if moodStore.entries.isEmpty {
                Text("Your check-ins will appear here once you start logging.")
                    .font(ZenFont.body(14))
                    .foregroundColor(.zenSubtext)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(moodStore.entries.prefix(30)) { entry in
                        MoodHistoryRow(entry: entry)
                    }
                }
            }
        }
    }
}

// MARK: - Chart Point Model

private struct ChartPoint: Identifiable {
    let id   = UUID()
    let date:  Date
    let score: Double
    let mood:  JournalEntry.Mood
}

// MARK: - Stat Pill

private struct MoodStatPill: View {
    let topText:   String?
    let imageName: String?
    let label:     String
    let color:     Color

    var body: some View {
        VStack(spacing: 6) {
            if let name = imageName {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            } else {
                Text(topText ?? "—")
                    .font(ZenFont.heading(18))
                    .foregroundColor(.zenText)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Mood History Row

private struct MoodHistoryRow: View {
    let entry: MoodEntry

    private var relativeDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(entry.date)     { return "Today" }
        if cal.isDateInYesterday(entry.date) { return "Yesterday" }
        let fmt = DateFormatter(); fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Mood image badge
            Image(entry.mood.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(entry.mood.color.opacity(0.20))
                )

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.mood.rawValue)
                    .font(ZenFont.heading(14))
                    .foregroundColor(.zenText)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(ZenFont.body(13))
                        .foregroundColor(.zenSubtext)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 2) {
                Text(relativeDate)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                Text(entry.date, style: .time)
                    .font(ZenFont.caption(10))
                    .foregroundColor(.zenSubtext.opacity(0.55))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.65))
                .shadow(color: .zenDusk.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Mini Sparkline (used in HomeView widget)

/// A tiny 7-point line chart for embedding inside the HomeView mood card.
struct MoodSparkline: View {
    let entries: [MoodEntry]

    var body: some View {
        if entries.count > 1 {
            Chart(entries.suffix(7), id: \.id) { entry in
                LineMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Score", entry.mood.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.zenPurple.opacity(0.70), Color.zenSage.opacity(0.70)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Score", entry.mood.score)
                )
                .foregroundStyle(entry.mood.color)
                .symbolSize(18)
            }
            .chartYScale(domain: 0.5...5.5)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        } else {
            // Not enough data — show a subtle dotted line placeholder
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.zenSubtext.opacity(0.18))
                .frame(height: 2)
        }
    }
}
