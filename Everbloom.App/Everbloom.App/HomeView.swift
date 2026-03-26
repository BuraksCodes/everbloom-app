// HomeView.swift
// Everbloom — Anxiety & Panic Support App
// Main dashboard — personalized, clean Zen aesthetic

import SwiftUI

struct HomeView: View {
    @Binding var showingPanic: Bool
    @Binding var selectedTab: AppTab
    @EnvironmentObject var journalStore:  JournalStore
    @EnvironmentObject var authManager:   AuthManager
    @EnvironmentObject var moodStore:     MoodStore
    @State private var panicPulse          = false
    @State private var didAppear           = false
    @State private var showMoodTracker     = false
    @State private var showMoodCheckIn     = false
    @State private var showCrisisResources = false
    @State private var showSounds          = false

    // MARK: - Computed

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authManager.displayName
        switch hour {
        case 5..<12:  return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        case 17..<22: return "Good evening, \(name)"
        default:      return "Hi, \(name)"
        }
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<22: return "moon.stars.fill"
        default:      return "sparkles"
        }
    }

    private var greetingIconColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return Color(red: 1.0, green: 0.75, blue: 0.4)
        case 12..<17: return Color(red: 1.0, green: 0.82, blue: 0.3)
        case 17..<22: return Color(red: 0.72, green: 0.72, blue: 0.98)
        default:      return Color.zenLavender
        }
    }

    // Matches AffirmationLibrary in the widget target — same list, same hourly index.
    // Keep both in sync when adding new affirmations.
    private var currentAffirmation: String {
        let all: [String] = [
            "You are stronger than this moment.",
            "Breathe. You have survived every hard day so far.",
            "Peace is available to you, right now.",
            "Your feelings are valid. You are safe.",
            "One breath at a time is enough.",
            "Calm is always closer than it feels.",
            "You don't have to have it all figured out today.",
            "Small steps forward are still progress.",
            "Healing is not linear, and that is okay.",
            "You deserve the same compassion you give others.",
            "This feeling will pass. You are not stuck.",
            "Rest is productive. Your body deserves care.",
            "You are allowed to take up space.",
            "Anxiety is a wave — and waves always pass.",
            "You have gotten through 100% of your hard days.",
            "It is okay to ask for help. Strength knows its limits.",
            "Your mind is learning. Give it patience.",
            "Right now, in this moment, you are okay.",
            "You are worthy of good things, even on bad days.",
            "Every exhale releases what no longer serves you.",
            "Your presence is enough. You don't need to perform.",
            "Fear is a visitor. It does not live here.",
            "The present moment is always manageable.",
            "Growth happens quietly, even when you can't see it.",
            "You are not your thoughts. You are the sky they move through.",
            "Gentleness is not weakness — it is wisdom.",
            "Even the hardest winters end in spring.",
            "You are doing the best you can. That is enough.",
            "Stillness is a kind of courage too.",
            "You belong here, exactly as you are.",
        ]
        let totalHours = Int(Date().timeIntervalSince1970) / 3600
        return all[totalHours % all.count]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Soft layered background
            ZStack {
                ZenGradient.background.ignoresSafeArea()
                // Decorative blurred orbs
                Circle()
                    .fill(Color.zenLavender.opacity(0.28))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -80, y: -200)
                Circle()
                    .fill(Color.zenPeach.opacity(0.22))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: 140, y: 300)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    headerSection
                        .animatedEntry(delay: 0.05, appeared: didAppear)

                    affirmationBanner
                        .animatedEntry(delay: 0.12, appeared: didAppear)

                    moodWidget
                        .animatedEntry(delay: 0.18, appeared: didAppear)

                    panicButtonSection
                        .animatedEntry(delay: 0.26, appeared: didAppear)

                    crisisBanner
                        .animatedEntry(delay: 0.30, appeared: didAppear)

                    featureGrid
                        .animatedEntry(delay: 0.28, appeared: didAppear)

                    if let latest = journalStore.entries.first {
                        recentJournalCard(latest)
                            .animatedEntry(delay: 0.36, appeared: didAppear)
                    }
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { didAppear = true }
            panicPulse = true
        }
        .sheet(isPresented: $showMoodTracker) {
            MoodTrackerView()
                .environmentObject(moodStore)
        }
        .sheet(isPresented: $showMoodCheckIn) {
            MoodCheckInView()
                .environmentObject(moodStore)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showCrisisResources) {
            CrisisResourcesView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                // SF Symbol for time-of-day — emoji broke on iOS 26 with custom fonts
                HStack(spacing: 6) {
                    Text(greetingText)
                        .font(ZenFont.title(22))
                        .foregroundColor(.zenText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: greetingIcon)
                        .font(.system(size: 18, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(greetingIconColor)
                }
                Text("How are you feeling today?")
                    .font(ZenFont.body(15))
                    .foregroundColor(.zenSubtext)
            }
            Spacer()
            // Logo top right
            Image("EvBloomLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: .zenLavender.opacity(0.5), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Crisis Banner

    private var crisisBanner: some View {
        Button { showCrisisResources = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.zenRose.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.zenRose)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Need immediate support?")
                        .font(ZenFont.heading(13))
                        .foregroundColor(.zenText)
                    Text("Crisis resources — 988, Crisis Text Line & more")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.zenSubtext.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .shadow(color: .zenRose.opacity(0.08), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.zenRose.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(FeatureCardButtonStyle())
    }

    // MARK: - Affirmation Banner

    private var affirmationBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.zenPurple.opacity(0.7))

            Text(currentAffirmation)
                .font(ZenFont.body(14))
                .foregroundColor(.zenText.opacity(0.75))
                .italic()
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.zenLavender.opacity(0.30), Color.zenPeach.opacity(0.20)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - Panic Button

    private var panicButtonSection: some View {
        VStack(spacing: 0) {
            // Top label
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Panic Relief")
                        .font(ZenFont.heading(16))
                        .foregroundColor(.zenText)
                    Text("Tap if you feel overwhelmed")
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                }
                Spacer()
                // SOS badge
                Text("SOS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.zenRose.opacity(0.85))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)

            // Pulsing button
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.zenRose.opacity(panicPulse ? 0.0 : 0.20), lineWidth: 1.5)
                        .frame(width: CGFloat(140 + i * 28))
                        .scaleEffect(panicPulse ? 1.4 : 1.0)
                        .animation(
                            .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.55),
                            value: panicPulse
                        )
                }

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showingPanic = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.76, blue: 0.82),
                                        Color(red: 0.88, green: 0.72, blue: 0.94)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 118, height: 118)
                            .shadow(color: Color(red: 0.88, green: 0.55, blue: 0.65).opacity(0.45), radius: 22, x: 0, y: 8)

                        VStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                            Text("I need help")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                        }
                    }
                }
                .buttonStyle(PanicButtonStyle())
            }
            .frame(height: 210)

            Text("Grounding · Breathing · Affirmation")
                .font(ZenFont.caption(12))
                .foregroundColor(.zenSubtext)
                .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .shadow(color: .zenDusk.opacity(0.07), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
    }

    // MARK: - Mood Widget

    @ViewBuilder
    private var moodWidget: some View {
        if let today = moodStore.todaysEntry {
            // Already checked in — show mood + sparkline + tap to open tracker
            Button { showMoodTracker = true } label: {
                HStack(spacing: 14) {
                    Image(today.mood.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(today.mood.color.opacity(0.22))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("TODAY'S MOOD")
                            .font(ZenFont.caption(10))
                            .foregroundColor(.zenSubtext)
                            .tracking(1.2)
                        Text("Feeling \(today.mood.rawValue.lowercased())")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                        if let note = today.note, !note.isEmpty {
                            Text(note)
                                .font(ZenFont.caption(12))
                                .foregroundColor(.zenSubtext)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Mini 7-day sparkline
                    MoodSparkline(entries: moodStore.recentEntries(days: 7))
                        .frame(width: 56, height: 30)
                        .padding(.trailing, 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.zenSubtext.opacity(0.45))
                }
                .padding(16)
                .zenCard()
            }
            .buttonStyle(FeatureCardButtonStyle())

        } else {
            // Not checked in yet — gentle prompt
            Button { showMoodCheckIn = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.zenLavender.opacity(0.28))
                            .frame(width: 48, height: 48)
                        Image(systemName: "face.smiling")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.zenPurple.opacity(0.75))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("DAILY CHECK-IN")
                            .font(ZenFont.caption(10))
                            .foregroundColor(.zenSubtext)
                            .tracking(1.2)
                        Text("How are you feeling?")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                    }

                    Spacer()

                    Text("Log now")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.zenPurple.opacity(0.80))
                        .clipShape(Capsule())
                }
                .padding(16)
                .zenCard()
            }
            .buttonStyle(FeatureCardButtonStyle())
        }
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOOLS FOR YOU")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(1.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                FeatureCard(
                    title: "Breathe",
                    subtitle: "\(BreathingTechnique.all.count) techniques",
                    icon: "wind",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.70, green: 0.83, blue: 0.97), Color(red: 0.78, green: 0.70, blue: 0.96)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { selectedTab = .breathe }

                FeatureCard(
                    title: "Sounds",
                    subtitle: "6 calming tracks",
                    icon: "waveform",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.70, green: 0.90, blue: 0.80), Color(red: 0.70, green: 0.86, blue: 0.97)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { showSounds = true }

                FeatureCard(
                    title: "Journal",
                    subtitle: journalStore.entries.count == 0 ? "Start writing" : "\(journalStore.entries.count) entries",
                    icon: "book.closed.fill",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.98, green: 0.82, blue: 0.74), Color(red: 0.96, green: 0.74, blue: 0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { selectedTab = .journal }

                FeatureCard(
                    title: "Grounding",
                    subtitle: "5-4-3-2-1 method",
                    icon: "leaf.fill",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.72, green: 0.88, blue: 0.78), Color(red: 0.78, green: 0.83, blue: 0.96)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { showingPanic = true }

                FeatureCard(
                    title: "Meditate",
                    subtitle: "\(MeditationLibrary.sessions.count) sessions",
                    icon: "figure.mind.and.body",
                    gradient: LinearGradient(
                        colors: [Color(red: 0.62, green: 0.44, blue: 0.92), Color(red: 0.82, green: 0.68, blue: 1.00)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                ) { selectedTab = .meditate }
            }
        }
        .sheet(isPresented: $showSounds) {
            SoundsView()
        }
    }

    // MARK: - Recent Journal

    private func recentJournalCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.zenPurple.opacity(0.7))
                    Text("LAST ENTRY")
                        .font(ZenFont.caption(11))
                        .foregroundColor(.zenSubtext)
                        .tracking(1.2)
                }
                Spacer()
                Text(entry.date, style: .date)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
            }

            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                .font(ZenFont.heading(16))
                .foregroundColor(.zenText)

            Text(entry.body)
                .font(ZenFont.body(14))
                .foregroundColor(.zenSubtext)
                .lineLimit(2)
                .lineSpacing(3)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(entry.mood.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text(entry.mood.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.zenText.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(entry.mood.color.opacity(0.5))
                .clipShape(Capsule())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.zenSubtext.opacity(0.5))
            }
        }
        .padding(18)
        .zenCard()
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon bubble
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(gradient)
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.white)
                }

                Spacer()

                Text(title)
                    .font(ZenFont.heading(16))
                    .foregroundColor(.zenText)
                Text(subtitle)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                    .padding(.top, 1)
            }
            .padding(16)
            .frame(height: 128)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .shadow(color: .zenDusk.opacity(0.07), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(FeatureCardButtonStyle())
    }
}

struct FeatureCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Panic Button Style

struct PanicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    HomeView(showingPanic: .constant(false), selectedTab: .constant(.home))
        .environmentObject(JournalStore())
        .environmentObject(AudioManager())
        .environmentObject(AuthManager())
        .environmentObject(MoodStore())
}
