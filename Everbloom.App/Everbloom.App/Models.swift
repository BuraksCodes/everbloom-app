// Models.swift
// Everbloom — Anxiety & Panic Support App

import Foundation
import SwiftUI
import Combine

// MARK: - Journal Entry

struct JournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String
    var body: String
    var mood: Mood
    var promptUsed: String?

    enum Mood: String, CaseIterable, Codable {
        case anxious   = "Anxious"
        case stressed  = "Stressed"
        case neutral   = "Neutral"
        case calm      = "Calm"
        case grateful  = "Grateful"

        var emoji: String {
            switch self {
            case .anxious:  return "😰"
            case .stressed: return "😤"
            case .neutral:  return "😐"
            case .calm:     return "😌"
            case .grateful: return "🙏"
            }
        }

        var color: Color {
            switch self {
            case .anxious:  return .zenRose
            case .stressed: return .zenPeach
            case .neutral:  return .zenLavender
            case .calm:     return .zenSage
            case .grateful: return Color(red: 1.0, green: 0.90, blue: 0.72)
            }
        }

        var imageName: String {
            switch self {
            case .anxious:  return "MoodAnxious"
            case .stressed: return "MoodStressed"
            case .neutral:  return "MoodNeutral"
            case .calm:     return "MoodCalm"
            case .grateful: return "MoodGrateful"
            }
        }

        /// Numeric score for chart trend lines: 1 (worst) → 5 (best)
        var score: Int {
            switch self {
            case .anxious:  return 1
            case .stressed: return 2
            case .neutral:  return 3
            case .calm:     return 4
            case .grateful: return 5
            }
        }

        /// Reverse-map a chart score back to the nearest Mood
        static func from(score: Int) -> Mood {
            switch score {
            case 1:  return .anxious
            case 2:  return .stressed
            case 4:  return .calm
            case 5:  return .grateful
            default: return .neutral
            }
        }
    }
}

// MARK: - Mood Check-In Entry

/// Lightweight daily mood record — separate from a full JournalEntry.
/// Just a timestamp, mood, and an optional one-line note.
struct MoodEntry: Identifiable, Codable {
    var id:   UUID             = UUID()
    var date: Date             = Date()
    var mood: JournalEntry.Mood
    var note: String?          // filled via MoodCheckInView quick-note field
}

// MARK: - Breathing Technique

struct BreathingTechnique: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let description: String
    let phases: [BreathPhase]
    let totalRounds: Int
    let accentColor: Color

    struct BreathPhase: Identifiable {
        let id = UUID()
        let label: String
        let duration: Double
        let scale: CGFloat
        let instruction: String
        /// Spoken aloud by TTS at the start of each phase
        var voiceLabel: String { "\(label) for \(Int(duration)) seconds" }
    }

    static let box = BreathingTechnique(
        name: "Box Breathing",
        subtitle: "4 · 4 · 4 · 4",
        description: "Equal counts for inhale, hold, exhale, and hold. Proven to reduce cortisol and calm the nervous system.",
        phases: [
            BreathPhase(label: "Inhale", duration: 4, scale: 1.3, instruction: "Breathe in slowly through your nose"),
            BreathPhase(label: "Hold",   duration: 4, scale: 1.3, instruction: "Hold gently — stay still"),
            BreathPhase(label: "Exhale", duration: 4, scale: 0.7, instruction: "Release slowly through your mouth"),
            BreathPhase(label: "Hold",   duration: 4, scale: 0.7, instruction: "Rest before the next breath"),
        ],
        totalRounds: 4,
        accentColor: .zenSky
    )

    static let breathing478 = BreathingTechnique(
        name: "4-7-8 Breathing",
        subtitle: "4 · 7 · 8",
        description: "A natural tranquilizer. The extended exhale activates your parasympathetic nervous system.",
        phases: [
            BreathPhase(label: "Inhale", duration: 4, scale: 1.3,  instruction: "Inhale quietly through your nose"),
            BreathPhase(label: "Hold",   duration: 7, scale: 1.3,  instruction: "Hold your breath gently"),
            BreathPhase(label: "Exhale", duration: 8, scale: 0.7,  instruction: "Exhale completely through your mouth"),
        ],
        totalRounds: 4,
        accentColor: .zenLavender
    )

    static let diaphragmatic = BreathingTechnique(
        name: "Diaphragmatic",
        subtitle: "Belly breathing",
        description: "Deep belly breathing that engages your diaphragm, slowing heart rate and reducing anxiety.",
        phases: [
            BreathPhase(label: "Inhale", duration: 5, scale: 1.35, instruction: "Breathe into your belly, let it rise"),
            BreathPhase(label: "Pause",  duration: 2, scale: 1.35, instruction: "Feel the fullness in your belly"),
            BreathPhase(label: "Exhale", duration: 6, scale: 0.7,  instruction: "Let your belly fall slowly"),
        ],
        totalRounds: 5,
        accentColor: .zenSage
    )

    static let cyclicSighing = BreathingTechnique(
        name: "Cyclic Sighing",
        subtitle: "Double inhale · long exhale",
        description: "Stanford 2023 research found this the most effective real-time anxiety reducer. A deep sniff tops up your lungs, then a long exhale dumps CO₂ and instantly calms the body.",
        phases: [
            BreathPhase(label: "Inhale",      duration: 2,   scale: 1.15, instruction: "Breathe in deeply through your nose"),
            BreathPhase(label: "Sniff more",  duration: 1.5, scale: 1.35, instruction: "Top up your lungs with a sharp sniff"),
            BreathPhase(label: "Exhale",      duration: 6,   scale: 0.65, instruction: "Let all the air out slowly through your mouth"),
        ],
        totalRounds: 5,
        accentColor: .zenRose
    )

    static let coherent = BreathingTechnique(
        name: "Coherent Breathing",
        subtitle: "5 · 5  — maximize HRV",
        description: "Breathing at exactly 5 breaths per minute maximises heart rate variability, the key marker of a calm, resilient nervous system. Simple but deeply powerful.",
        phases: [
            BreathPhase(label: "Inhale",  duration: 5, scale: 1.3,  instruction: "Breathe in slowly and evenly through your nose"),
            BreathPhase(label: "Exhale",  duration: 5, scale: 0.7,  instruction: "Release slowly and completely"),
        ],
        totalRounds: 6,
        accentColor: .zenPeach
    )

    static let extendedExhale = BreathingTechnique(
        name: "Extended Exhale",
        subtitle: "4 · 8  — fast calm",
        description: "Doubling your exhale time directly activates the parasympathetic nervous system. One of the fastest ways to reduce a racing heart and anxious thoughts.",
        phases: [
            BreathPhase(label: "Inhale",  duration: 4, scale: 1.3,  instruction: "Breathe in through your nose for 4 counts"),
            BreathPhase(label: "Exhale",  duration: 8, scale: 0.65, instruction: "Exhale slowly and fully for 8 counts"),
        ],
        totalRounds: 5,
        accentColor: Color(red: 0.78, green: 0.85, blue: 0.95)
    )

    static let all: [BreathingTechnique] = [.box, .breathing478, .diaphragmatic, .cyclicSighing, .coherent, .extendedExhale]

    var recommendedTag: String? {
        switch name {
        case "Cyclic Sighing":    return "★ Best for Panic"
        case "Box Breathing":     return "★ Focus & Calm"
        case "4-7-8 Breathing":   return "★ Sleep & Rest"
        case "Coherent Breathing":return "★ Daily Practice"
        default: return nil
        }
    }

    /// SF Symbol name unique to each technique — used in library cards and detail view
    var sfSymbol: String {
        switch name {
        case "Box Breathing":      return "square"
        case "4-7-8 Breathing":    return "moon.fill"
        case "Diaphragmatic":      return "circle.bottomhalf.filled"
        case "Cyclic Sighing":     return "arrow.2.circlepath"
        case "Coherent Breathing": return "waveform.path.ecg"
        case "Extended Exhale":    return "arrow.down.to.line.compact"
        default:                   return "wind"
        }
    }

    /// Icon shown inside the circle for each breathing phase type
    static func phaseIcon(for label: String) -> String {
        switch label {
        case "Inhale":     return "arrow.up.circle.fill"
        case "Hold", "Pause": return "pause.circle.fill"
        case "Exhale":     return "arrow.down.circle.fill"
        case "Sniff more": return "arrow.up.circle.fill"
        default:           return "circle.fill"
        }
    }
}

// MARK: - Sound Option

struct SoundOption: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let fileName: String
    let fileExtension: String
    let accentColor: Color
    let description: String
}

extension SoundOption {
    static let all: [SoundOption] = [
        SoundOption(name: "Rain",        icon: "cloud.rain.fill", fileName: "rain",       fileExtension: "mp3", accentColor: .zenSky,      description: "Gentle rainfall on leaves"),
        SoundOption(name: "Forest",      icon: "leaf.fill",       fileName: "forest",     fileExtension: "mp3", accentColor: .zenSage,     description: "Birds and rustling trees"),
        SoundOption(name: "Ocean",       icon: "water.waves",     fileName: "ocean",      fileExtension: "mp3", accentColor: Color(red: 0.6, green: 0.82, blue: 0.92), description: "Rolling waves on shore"),
        SoundOption(name: "White Noise", icon: "waveform",        fileName: "whitenoise", fileExtension: "mp3", accentColor: .zenLavender, description: "Smooth, constant static"),
        SoundOption(name: "Stream",      icon: "drop.fill",       fileName: "stream",     fileExtension: "mp3", accentColor: .zenSky,      description: "Babbling brook in a forest"),
        SoundOption(name: "Wind Bells",  icon: "wind",            fileName: "windbells",  fileExtension: "mp3", accentColor: .zenPeach,    description: "Soft chimes in the breeze"),
    ]
}

// MARK: - Grounding Step

struct GroundingStep: Identifiable {
    let id = UUID()
    let number: Int
    let sense: String
    let prompt: String
    let icon: String
    let color: Color
    /// Spoken aloud by TTS when this step is shown
    var voicePrompt: String { prompt }
}

extension GroundingStep {
    static let fiveSteps: [GroundingStep] = [
        GroundingStep(number: 5, sense: "See",   prompt: "Name 5 things you can see around you right now",        icon: "eye.fill",         color: .zenSky),
        GroundingStep(number: 4, sense: "Touch", prompt: "Notice 4 things you can physically feel or touch",     icon: "hand.raised.fill", color: .zenSage),
        GroundingStep(number: 3, sense: "Hear",  prompt: "Identify 3 sounds you can hear in this moment",        icon: "ear.fill",         color: .zenLavender),
        GroundingStep(number: 2, sense: "Smell", prompt: "Find 2 things you can smell, or recall a calm scent",  icon: "nose.fill",        color: .zenPeach),
        GroundingStep(number: 1, sense: "Taste", prompt: "Notice 1 thing you can taste, or take a sip of water", icon: "mouth.fill",       color: .zenRose),
    ]
}

// MARK: - Journal Store

// Swift 6 fix: @MainActor on the class breaks @Published synthesis.
// Solution: no @MainActor on the class; mark individual methods @MainActor instead.
class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var isSyncing = false
    /// Set by PanicButtonView to open NewEntryView pre-filled after a panic session.
    @Published var panicSessionDraft: String? = nil

    private let localKey = "journal_entries_v1"
    private let firestore = FirestoreManager.shared

    @MainActor
    init() { loadLocal() }

    // MARK: - Public API

    @MainActor
    func save(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        persistLocal()
        Task { try? await firestore.saveJournalEntry(entry) }
    }

    @MainActor
    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { entries[$0] }
        entries.remove(atOffsets: offsets)
        persistLocal()
        Task {
            for entry in toDelete {
                try? await firestore.deleteJournalEntry(entry)
            }
        }
    }

    @MainActor
    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persistLocal()
        Task { try? await firestore.deleteJournalEntry(entry) }
    }

    // MARK: - Stats

    /// Consecutive days with at least one entry (today counts if logged)
    @MainActor
    var currentStreak: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 0

        // If nothing written today, start streak check from yesterday
        let hasToday = entries.contains { cal.isDate($0.date, inSameDayAs: today) }
        let startOffset = hasToday ? 0 : 1

        for i in startOffset..<365 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { break }
            if entries.contains(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Number of entries written in the current calendar week
    @MainActor
    var entriesThisWeek: Int {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }

    /// The mood logged most frequently across all entries
    @MainActor
    var mostUsedMood: JournalEntry.Mood? {
        guard !entries.isEmpty else { return nil }
        let counts = Dictionary(grouping: entries, by: \.mood).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Call this after sign-in to pull entries from Firestore
    @MainActor
    func syncFromCloud() {
        isSyncing = true
        Task { @MainActor in
            if let cloud = try? await firestore.loadJournalEntries(), !cloud.isEmpty {
                entries = cloud
                persistLocal()
            }
            isSyncing = false
        }
    }

    // MARK: - Local cache (UserDefaults)

    @MainActor
    private func persistLocal() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    @MainActor
    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data)
        else { return }
        entries = decoded
    }
}

// MARK: - Journal Prompts

struct JournalPrompts {

    // ── Mood-specific banks ──────────────────────────────────────────────────

    static let anxious: [String] = [
        "What triggered this feeling? Walk me through what happened.",
        "Where do you feel anxiety in your body right now?",
        "What is one thing you know for certain is true right now?",
        "What would you tell a close friend feeling this anxious?",
        "Name 5 things you can see, 4 you can touch, 3 you can hear.",
        "What fear is underneath this anxiety? Is that fear realistic?",
        "What has helped you get through anxiety before?",
        "If anxiety were a weather pattern, what would it look like today?",
    ]

    static let stressed: [String] = [
        "What is overwhelming you most right now? List it all out.",
        "Which of those things can you actually control today?",
        "What would 'good enough' look like for today — not perfect?",
        "Who or what is draining your energy right now?",
        "What is one thing you can put down or say no to?",
        "What does your body need right now — sleep, food, movement?",
        "Write out everything on your to-do list, then circle just one.",
        "When did you last feel truly rested? What was different then?",
    ]

    static let neutral: [String] = [
        "Write freely for 5 minutes without stopping or editing.",
        "What have you been thinking about most today?",
        "Describe your day so far as if telling a story to a friend.",
        "What do you want more of in your life right now?",
        "What is something small you did well today?",
        "What thought keeps repeating? Is it true? Is it helpful?",
        "What does a good version of tomorrow look like?",
        "What are you looking forward to, even something small?",
    ]

    static let calm: [String] = [
        "What helped you feel calm today? How can you do more of it?",
        "Describe this peaceful feeling so you can return to it.",
        "What is working well in your life right now?",
        "What do you want to carry forward from this moment?",
        "Write a letter to a future stressed version of yourself.",
        "What are you learning about yourself lately?",
        "What does a life that feels like this more often look like?",
        "Who in your life makes you feel at peace? What do they do?",
    ]

    static let grateful: [String] = [
        "List 10 things you're grateful for — go beyond the obvious.",
        "Who has made your life better recently? What did they do?",
        "What small, ordinary thing do you appreciate that you might overlook?",
        "Describe a moment from the past week that made you smile.",
        "What about your own character are you grateful for today?",
        "What challenge turned into a gift or lesson over time?",
        "Write a thank-you letter to someone who helped shape who you are.",
        "What does abundance look like in your life right now?",
    ]

    // ── General (fallback) ────────────────────────────────────────────────────

    static let all: [String] =
        anxious + stressed + neutral + calm + grateful

    static var random: String { all.randomElement() ?? all[0] }

    /// Returns mood-matched prompts, shuffled for variety
    static func suggestions(for mood: JournalEntry.Mood) -> [String] {
        let base: [String]
        switch mood {
        case .anxious:  base = anxious
        case .stressed: base = stressed
        case .neutral:  base = neutral
        case .calm:     base = calm
        case .grateful: base = grateful
        }
        return base.shuffled()
    }
}

// ============================================================
// MARK: - Meditation Models
// ============================================================

// MARK: Theme

enum MeditationTheme: String, CaseIterable {
    case lavender, sage, peach, sky, rose, amber, midnight

    var gradientColors: [Color] {
        switch self {
        case .lavender: return [Color(red: 0.62, green: 0.44, blue: 0.92),
                                Color(red: 0.80, green: 0.70, blue: 1.00)]
        case .sage:     return [Color(red: 0.36, green: 0.64, blue: 0.52),
                                Color(red: 0.62, green: 0.84, blue: 0.70)]
        case .peach:    return [Color(red: 0.92, green: 0.56, blue: 0.38),
                                Color(red: 1.00, green: 0.80, blue: 0.64)]
        case .sky:      return [Color(red: 0.28, green: 0.60, blue: 0.90),
                                Color(red: 0.58, green: 0.82, blue: 1.00)]
        case .rose:     return [Color(red: 0.84, green: 0.40, blue: 0.60),
                                Color(red: 1.00, green: 0.70, blue: 0.84)]
        case .amber:    return [Color(red: 0.86, green: 0.64, blue: 0.18),
                                Color(red: 1.00, green: 0.86, blue: 0.52)]
        case .midnight: return [Color(red: 0.14, green: 0.18, blue: 0.42),
                                Color(red: 0.28, green: 0.36, blue: 0.66)]
        }
    }

    /// Lighter tint for orb/glow — used inside the session player
    var orbColor: Color { gradientColors[1].opacity(0.50) }
}

// MARK: Category

enum MeditationCategory: String, CaseIterable, Identifiable {
    case all            = "All"
    case anxietyRelief  = "Anxiety"
    case sleep          = "Sleep"
    case focus          = "Focus"
    case selfCompassion = "Compassion"
    case bodyAwareness  = "Body Scan"
    case quickBreak     = "Quick"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:            return "square.grid.2x2.fill"
        case .anxietyRelief:  return "brain.head.profile"
        case .sleep:          return "moon.stars.fill"
        case .focus:          return "target"
        case .selfCompassion: return "heart.fill"
        case .bodyAwareness:  return "figure.mind.and.body"
        case .quickBreak:     return "bolt.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .all:            return .zenPurple
        case .anxietyRelief:  return .zenLavender
        case .sleep:          return Color(red: 0.28, green: 0.36, blue: 0.80)
        case .focus:          return .zenSky
        case .selfCompassion: return .zenRose
        case .bodyAwareness:  return .zenSage
        case .quickBreak:     return .zenPeach
        }
    }
}

// MARK: Step

struct MeditationStep: Identifiable {
    let id    = UUID()
    let startSeconds: Int   // when this guidance line becomes visible
    let text: String
}

// MARK: Session

struct MeditationSession: Identifiable {
    let id    = UUID()
    let title:           String
    let tagline:         String    // one-line description for the card
    let category:        MeditationCategory
    let durationMinutes: Int
    let theme:           MeditationTheme
    let sfSymbol:        String
    /// Bundled audio filename (no extension). nil = no ambient sound.
    let ambientSoundFile: String?
    let steps:           [MeditationStep]

    var totalSeconds: Int { durationMinutes * 60 }

    /// Returns the step whose text should currently be shown
    func currentStep(at elapsed: Int) -> MeditationStep {
        steps.last(where: { $0.startSeconds <= elapsed }) ?? steps[0]
    }
}

// MARK: Library

struct MeditationLibrary {

    static let sessions: [MeditationSession] = [

        // ── 1. Quick Anxiety Relief (3 min) ──────────────────────────────────
        MeditationSession(
            title: "Quick Anxiety Relief",
            tagline: "A 3-minute reset when anxiety peaks",
            category: .quickBreak,
            durationMinutes: 3,
            theme: .lavender,
            sfSymbol: "bolt.heart.fill",
            ambientSoundFile: "ambient_rain_gentle",
            steps: [
                MeditationStep(startSeconds:   0, text: "You are safe. This moment will pass."),
                MeditationStep(startSeconds:  10, text: "Breathe in for 4… hold 2… out for 6."),
                MeditationStep(startSeconds:  45, text: "Feel your feet firmly on the ground beneath you."),
                MeditationStep(startSeconds:  75, text: "Name 3 things you can see right now."),
                MeditationStep(startSeconds: 105, text: "Name 2 things you can physically touch. Notice the texture."),
                MeditationStep(startSeconds: 140, text: "Take one more slow, deep breath all the way down."),
                MeditationStep(startSeconds: 162, text: "The wave is passing. You are stronger than anxiety."),
                MeditationStep(startSeconds: 172, text: "Well done. 🌸"),
            ]
        ),

        // ── 2. Morning Calm (5 min) ───────────────────────────────────────────
        MeditationSession(
            title: "Morning Calm",
            tagline: "Start the day with intention and ease",
            category: .anxietyRelief,
            durationMinutes: 5,
            theme: .amber,
            sfSymbol: "sun.horizon.fill",
            ambientSoundFile: "ambient_birds_morning",
            steps: [
                MeditationStep(startSeconds:   0, text: "Welcome to a new day. Take a moment just for yourself."),
                MeditationStep(startSeconds:  20, text: "Notice how your body feels right now — no judgment, just awareness."),
                MeditationStep(startSeconds:  55, text: "Take three deep breaths and set an intention of ease for today."),
                MeditationStep(startSeconds: 100, text: "Picture the day ahead unfolding gently and smoothly."),
                MeditationStep(startSeconds: 150, text: "You carry inner calm with you wherever you go today."),
                MeditationStep(startSeconds: 210, text: "Inhale possibility… exhale resistance."),
                MeditationStep(startSeconds: 260, text: "Gently bring movement back to your fingers and toes."),
                MeditationStep(startSeconds: 290, text: "Open your eyes and step into your day with calm. 🌤"),
            ]
        ),

        // ── 3. Anxiety Relief (5 min) ─────────────────────────────────────────
        MeditationSession(
            title: "Calm the Storm",
            tagline: "Dissolve anxiety with breath and presence",
            category: .anxietyRelief,
            durationMinutes: 5,
            theme: .lavender,
            sfSymbol: "cloud.rain.fill",
            ambientSoundFile: "ambient_stream_forest",
            steps: [
                MeditationStep(startSeconds:   0, text: "Find a comfortable position and gently close your eyes."),
                MeditationStep(startSeconds:  15, text: "Take a slow, deep breath in through your nose… and release slowly."),
                MeditationStep(startSeconds:  40, text: "With each exhale, let tension melt away from your shoulders."),
                MeditationStep(startSeconds:  75, text: "Notice the weight of your body — supported completely right now."),
                MeditationStep(startSeconds: 110, text: "Your breath is your anchor. Stay with its rhythm."),
                MeditationStep(startSeconds: 150, text: "If your mind wanders, gently return — no judgment, just return."),
                MeditationStep(startSeconds: 195, text: "Breathe in calm… breathe out worry."),
                MeditationStep(startSeconds: 240, text: "You are safe in this moment. Nothing needs to be solved right now."),
                MeditationStep(startSeconds: 270, text: "Begin to gently deepen your breath."),
                MeditationStep(startSeconds: 290, text: "When you're ready, slowly open your eyes. You did well. 🌿"),
            ]
        ),

        // ── 4. Focus Reset (7 min) ────────────────────────────────────────────
        MeditationSession(
            title: "Focus Reset",
            tagline: "Clear mental fog and sharpen attention",
            category: .focus,
            durationMinutes: 7,
            theme: .sky,
            sfSymbol: "target",
            ambientSoundFile: "ambient_white_noise_soft",
            steps: [
                MeditationStep(startSeconds:   0, text: "Sit up straight and gently close your eyes."),
                MeditationStep(startSeconds:  20, text: "Take a full breath to clear the mental slate."),
                MeditationStep(startSeconds:  50, text: "Notice any mental chatter — acknowledge it, then let it go."),
                MeditationStep(startSeconds:  90, text: "Bring your attention to the sensation of breath at your nostrils."),
                MeditationStep(startSeconds: 150, text: "Stay with this single point. Sharp, clear, present."),
                MeditationStep(startSeconds: 210, text: "When thoughts arise, note 'thinking' and gently return."),
                MeditationStep(startSeconds: 270, text: "You are cultivating mental clarity right now."),
                MeditationStep(startSeconds: 330, text: "Picture your mind as a calm, clear pool of water."),
                MeditationStep(startSeconds: 385, text: "Begin to deepen your breath and reconnect with the room."),
                MeditationStep(startSeconds: 410, text: "Open your eyes. You are focused and ready. 🎯"),
            ]
        ),

        // ── 5. Self-Compassion (8 min) ────────────────────────────────────────
        MeditationSession(
            title: "Self-Compassion",
            tagline: "Offer yourself the kindness you deserve",
            category: .selfCompassion,
            durationMinutes: 8,
            theme: .rose,
            sfSymbol: "heart.fill",
            ambientSoundFile: "ambient_piano_soft",
            steps: [
                MeditationStep(startSeconds:   0, text: "Place one hand gently over your heart."),
                MeditationStep(startSeconds:  20, text: "Feel the warmth and gentle pressure of your hand."),
                MeditationStep(startSeconds:  55, text: "Breathe in, and say silently: 'May I be kind to myself.'"),
                MeditationStep(startSeconds: 100, text: "'May I give myself the compassion I deserve.'"),
                MeditationStep(startSeconds: 150, text: "Think of a difficulty you're facing right now."),
                MeditationStep(startSeconds: 195, text: "Acknowledge: 'This is a moment of suffering. Suffering is part of life.'"),
                MeditationStep(startSeconds: 255, text: "'I am not alone in this feeling.'"),
                MeditationStep(startSeconds: 315, text: "Now offer yourself what you would offer a dear friend."),
                MeditationStep(startSeconds: 375, text: "'May I be peaceful. May I be happy. May I be free from suffering.'"),
                MeditationStep(startSeconds: 440, text: "Rest in this warmth for a moment."),
                MeditationStep(startSeconds: 465, text: "Carry this kindness with you. You deserve it. 💗"),
            ]
        ),

        // ── 6. Gratitude Practice (8 min) ─────────────────────────────────────
        MeditationSession(
            title: "Gratitude Practice",
            tagline: "Cultivate joy through appreciation",
            category: .selfCompassion,
            durationMinutes: 8,
            theme: .amber,
            sfSymbol: "sparkles",
            ambientSoundFile: "ambient_gratitude",
            steps: [
                MeditationStep(startSeconds:   0, text: "Settle in and close your eyes with a gentle smile."),
                MeditationStep(startSeconds:  20, text: "Think of one person who has made your life richer."),
                MeditationStep(startSeconds:  65, text: "Recall a specific moment with them. Let it fill you."),
                MeditationStep(startSeconds: 120, text: "Now think of something simple — warmth, breath, this moment."),
                MeditationStep(startSeconds: 180, text: "Notice how gratitude feels in your chest. Let it expand."),
                MeditationStep(startSeconds: 240, text: "Bring to mind a challenge that taught you something valuable."),
                MeditationStep(startSeconds: 295, text: "Thank that experience for its lesson."),
                MeditationStep(startSeconds: 355, text: "Silently repeat: 'I have enough. I am enough. I am grateful.'"),
                MeditationStep(startSeconds: 430, text: "Rest in this feeling."),
                MeditationStep(startSeconds: 460, text: "Carry this gratitude into the rest of your day. ✨"),
            ]
        ),

        // ── 7. Body Scan (10 min) ─────────────────────────────────────────────
        MeditationSession(
            title: "Body Scan",
            tagline: "Travel through your body with gentle awareness",
            category: .bodyAwareness,
            durationMinutes: 10,
            theme: .sage,
            sfSymbol: "figure.mind.and.body",
            ambientSoundFile: "ambient_ocean_waves",
            steps: [
                MeditationStep(startSeconds:   0, text: "Lie down or sit comfortably. Close your eyes."),
                MeditationStep(startSeconds:  25, text: "Take three slow, full breaths to settle in."),
                MeditationStep(startSeconds:  65, text: "Bring awareness to the top of your head. Notice any sensation."),
                MeditationStep(startSeconds: 110, text: "Let your attention travel slowly down to your face and jaw."),
                MeditationStep(startSeconds: 160, text: "Notice your neck and shoulders. Gently release any tension."),
                MeditationStep(startSeconds: 220, text: "Move awareness into your chest and heart area."),
                MeditationStep(startSeconds: 280, text: "Notice your belly rising and falling with each breath."),
                MeditationStep(startSeconds: 340, text: "Travel through your lower back and hips."),
                MeditationStep(startSeconds: 400, text: "Continue down through your legs, knees, calves…"),
                MeditationStep(startSeconds: 460, text: "…all the way to the soles of your feet. Feel their weight."),
                MeditationStep(startSeconds: 520, text: "Now hold your whole body in awareness at once."),
                MeditationStep(startSeconds: 565, text: "Gently deepen your breath. Wiggle your fingers and toes."),
                MeditationStep(startSeconds: 585, text: "Open your eyes whenever you're ready. 🌿"),
            ]
        ),

        // ── 8. Progressive Relaxation (12 min) ───────────────────────────────
        MeditationSession(
            title: "Progressive Relaxation",
            tagline: "Release tension muscle by muscle",
            category: .bodyAwareness,
            durationMinutes: 12,
            theme: .sage,
            sfSymbol: "waveform.path",
            ambientSoundFile: "ambient_relaxation_music",
            steps: [
                MeditationStep(startSeconds:   0, text: "Lie down comfortably. Close your eyes and take a long breath."),
                MeditationStep(startSeconds:  30, text: "Clench your fists tightly for 5 seconds… then release."),
                MeditationStep(startSeconds:  75, text: "Feel the contrast between tension and complete relaxation."),
                MeditationStep(startSeconds: 110, text: "Tense your shoulders up to your ears… hold… and let go."),
                MeditationStep(startSeconds: 160, text: "Notice the warmth and heaviness as those muscles release."),
                MeditationStep(startSeconds: 210, text: "Clench your jaw and facial muscles… then soften completely."),
                MeditationStep(startSeconds: 260, text: "Now tighten your core and back… breathe in… and release."),
                MeditationStep(startSeconds: 320, text: "Squeeze your thighs and glutes… hold… let them melt."),
                MeditationStep(startSeconds: 380, text: "Point your toes and flex your calves… hold… release."),
                MeditationStep(startSeconds: 440, text: "Now your entire body is soft and heavy with relaxation."),
                MeditationStep(startSeconds: 510, text: "Breathe naturally. Notice how different your body feels now."),
                MeditationStep(startSeconds: 590, text: "Carry this deep sense of release with you. 🌊"),
                MeditationStep(startSeconds: 700, text: "When ready, gently wiggle back to awareness."),
            ]
        ),

        // ── 9. Sleep Preparation (10 min) ─────────────────────────────────────
        MeditationSession(
            title: "Sleep Preparation",
            tagline: "Ease into deep, restful sleep",
            category: .sleep,
            durationMinutes: 10,
            theme: .midnight,
            sfSymbol: "moon.stars.fill",
            ambientSoundFile: "ambient_rain_deep",
            steps: [
                MeditationStep(startSeconds:   0, text: "Lie in a comfortable position. Allow your eyes to gently close."),
                MeditationStep(startSeconds:  30, text: "With each exhale, let your body sink deeper into relaxation."),
                MeditationStep(startSeconds:  75, text: "Breathe in for 4 counts… and out for 8 counts."),
                MeditationStep(startSeconds: 140, text: "Picture a warm, golden light entering with each inhale."),
                MeditationStep(startSeconds: 200, text: "With each exhale, release the events of the day."),
                MeditationStep(startSeconds: 270, text: "Your to-do list can wait. Right now, there is only this moment."),
                MeditationStep(startSeconds: 340, text: "Let thoughts drift past like leaves floating on a quiet stream."),
                MeditationStep(startSeconds: 420, text: "Your body is safe. Your mind can rest completely."),
                MeditationStep(startSeconds: 500, text: "Allow yourself to drift toward deep, peaceful sleep."),
                MeditationStep(startSeconds: 560, text: "Goodnight. You did well today. 🌙"),
            ]
        ),

        // ── 10. Evening Wind Down (15 min) ────────────────────────────────────
        MeditationSession(
            title: "Evening Wind Down",
            tagline: "A gentle ritual to close the day",
            category: .sleep,
            durationMinutes: 15,
            theme: .midnight,
            sfSymbol: "moon.fill",
            ambientSoundFile: "ambient_evening",
            steps: [
                MeditationStep(startSeconds:   0, text: "Find a quiet, comfortable position. The day is complete."),
                MeditationStep(startSeconds:  30, text: "Take three slow, deep breaths and let your shoulders drop."),
                MeditationStep(startSeconds:  80, text: "Bring to mind one thing from today that you're grateful for."),
                MeditationStep(startSeconds: 140, text: "Now release anything that didn't go as planned. It's okay."),
                MeditationStep(startSeconds: 200, text: "You showed up today. That's enough."),
                MeditationStep(startSeconds: 260, text: "Breathe in peace… breathe out the residue of the day."),
                MeditationStep(startSeconds: 330, text: "Imagine a gentle wave washing over you, cool and soothing."),
                MeditationStep(startSeconds: 410, text: "Let your thoughts slow down like traffic late at night."),
                MeditationStep(startSeconds: 500, text: "Your body has worked hard. Let it rest completely now."),
                MeditationStep(startSeconds: 590, text: "You are safe. You are loved. You are enough."),
                MeditationStep(startSeconds: 680, text: "Let sleep come naturally, in its own perfect time. 🌙"),
                MeditationStep(startSeconds: 800, text: "Rest. Dream well."),
            ]
        ),
    ]

    /// Filter by category (returns all if .all)
    static func sessions(for category: MeditationCategory) -> [MeditationSession] {
        guard category != .all else { return sessions }
        return sessions.filter { $0.category == category }
    }
}
