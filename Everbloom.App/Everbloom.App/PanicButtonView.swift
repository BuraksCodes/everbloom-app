// PanicButtonView.swift
// Everbloom — Anxiety & Panic Support App
// Emergency panic flow: grounding → breathing → affirmation
// v2: Ambient rain sound (free) + TTS voice guidance (premium)

import SwiftUI
import AVFoundation

// MARK: - Panic Audio Manager

/// Stored as @State in PanicButtonView (a @MainActor View), so all property access
/// happens on the main actor. @MainActor here makes that isolation explicit and
/// silences Swift 6 "main actor-isolated property 'phraseCache'" warnings.
@MainActor
final class PanicAudioManager {

    // ── Ambient rain ──
    private var rainPlayer: AVAudioPlayer?

    // ── ElevenLabs TTS (routed through APIProxy → Cloudflare Worker) ──

    // Stores ElevenLabs voice IDs — see APIProxy.voiceFemale / APIProxy.voiceMale
    var voiceName: String = APIProxy.voiceFemale  // British female therapist (default)

    // phrase → cached temp-file URL (AVAudioPlayer works reliably from file, not raw Data)
    private var phraseCache: [String: URL] = [:]
    private var ttsPlayer:   AVAudioPlayer?

    // Version counter — incremented on every clearCache() call.
    // Prewarm tasks check this before writing to the cache so that stale
    // pre-warms can't overwrite the cache after switching voices.
    private var cacheVersion: Int = 0

    // ── Fallback synthesizer (used only if network unavailable) ──
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        setupAudioSession()
        synthesizer.usesApplicationAudioSession = true
        prepareRain()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        // .mixWithOthers only — NO .duckOthers.
        // Using .duckOthers caused the ambient sounds in AudioManager to continuously
        // fade in/out as TTS phrases played and paused (iOS auto-ducks between phrases).
        // The TTS voice (vol 1.0) is loud enough over the rain (vol 0.30) without ducking.
        // Both AudioManager and PanicAudioManager share the same AVAudioSession, so they
        // must use identical options to avoid fighting over the session config.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[PanicAudioManager] Audio session error: \(error)")
            #endif
        }
    }

    // MARK: - Rain

    private func prepareRain() {
        guard let url = Bundle.main.url(forResource: "rain_ambient", withExtension: "mp3") else { return }
        rainPlayer = try? AVAudioPlayer(contentsOf: url)
        rainPlayer?.numberOfLoops = -1
        rainPlayer?.volume = 0.30
        rainPlayer?.prepareToPlay()
    }

    func startRain() { rainPlayer?.play() }

    func stopRain() {
        rainPlayer?.stop()
        rainPlayer?.currentTime = 0
    }

    // MARK: - OpenAI TTS

    /// Clear the phrase cache — call when the voice gender changes so phrases re-generate.
    /// Bumps cacheVersion so any in-progress prewarm tasks know their results are stale
    /// and won't overwrite the now-empty cache with the old voice's audio.
    func clearCache() {
        cacheVersion += 1
        phraseCache.values.forEach { try? FileManager.default.removeItem(at: $0) }
        phraseCache.removeAll()
    }

    /// Pre-generate audio for all phrases in parallel so playback is instant later.
    /// Captures cacheVersion at start; discards results if the version changed (i.e. voice was
    /// switched mid-flight) so stale audio from the previous voice never pollutes the cache.
    func prewarm(phrases: [String]) async {
        let myVersion = cacheVersion

        // Pre-filter on current executor — safe to access phraseCache here
        let toFetch = phrases.filter { phraseCache[$0] == nil }
        guard !toFetch.isEmpty else { return }

        // Capture primitives so no self reference is needed inside addTask
        let voice = voiceName

        var results: [(String, URL)] = []
        await withTaskGroup(of: (String, URL?).self) { group in
            for phrase in toFetch {
                group.addTask {
                    // Route through the Cloudflare Worker proxy — key never leaves the server
                    let url = await APIProxy.fetchTTS(phrase: phrase, voice: voice)
                    return (phrase, url)
                }
            }
            for await (phrase, maybeURL) in group {
                if let url = maybeURL { results.append((phrase, url)) }
            }
        }

        // Back on the original executor — write to cache only if voice hasn't changed
        guard cacheVersion == myVersion else { return }
        for (phrase, url) in results { phraseCache[phrase] = url }
    }

    /// Speak text — instant from cache, async fetch on first use, fallback to system TTS.
    /// Voice guidance in Panic Relief is always free — it's a safety feature.
    func speak(_ text: String, isPremium: Bool = true) {
        guard !text.isEmpty else { return }
        ttsPlayer?.stop()
        synthesizer.stopSpeaking(at: .word)

        if let cached = phraseCache[text] {
            playFromFile(cached)
        } else {
            let voice = voiceName
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let url = await APIProxy.fetchTTS(phrase: text, voice: voice) {
                    self.phraseCache[text] = url
                    self.playFromFile(url)
                } else {
                    self.fallbackSpeak(text)
                }
            }
        }
    }

    /// Write MP3 to a temp file and play from there.
    /// Playing from a file URL is far more reliable than AVAudioPlayer(data:) —
    /// eliminates the choppiness / premature cut-off that raw Data playback causes.
    private func playFromFile(_ url: URL) {
        do {
            ttsPlayer = try AVAudioPlayer(contentsOf: url)
            ttsPlayer?.volume = 1.0
            ttsPlayer?.prepareToPlay()
            ttsPlayer?.play()
        } catch {
            #if DEBUG
            print("[TTS] Playback error: \(error)")
            #endif
        }
    }

    /// On-device fallback — sounds robotic but better than silence.
    private func fallbackSpeak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let all = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = all.first(where: { $0.language.hasPrefix("en") && $0.quality == .premium })
                       ?? all.first(where: { $0.language.hasPrefix("en") && $0.quality == .enhanced })
                       ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate            = 0.42
        utterance.pitchMultiplier = 0.90
        utterance.volume          = 0.92
        utterance.preUtteranceDelay = 0.2
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        ttsPlayer?.stop()
        synthesizer.stopSpeaking(at: .word)
    }

    func teardown() {
        stopRain()
        stopSpeaking()
    }
}

// MARK: - PanicButtonView

struct PanicButtonView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var journalStore: JournalStore

    // Persisted voice preference — stores ElevenLabs voice ID
    @AppStorage("panicVoiceGender") private var voiceGender: String = APIProxy.voiceFemale

    @State private var audio = PanicAudioManager()

    @State private var stage: PanicStage = .intro
    @State private var groundingIndex = 0
    @State private var contentOpacity = 0.0
    @State private var breathPhase = 0
    @State private var breathScale: CGFloat = 0.7
    @State private var breathLabel = "Ready"
    @State private var breathTimer: Timer? = nil
    @State private var round = 1
    @State private var phaseSecondsLeft: Int = 0
    @State private var isBreathingActive = false

    // v3 additions
    @State private var selectedTechnique: BreathingTechnique = .box  // user-chosen in breathingChoice
    @State private var intensityLevel: Int = 2      // 1 mild · 2 moderate · 3 intense
    @State private var postRating: Int? = nil        // 1–5 feel-good after session
    @AppStorage("panicEpisodesJSON") private var episodesJSON: String = "[]"
    @State private var journalNudgeTapped: Bool = false  // tracks if journal nudge was used

    private var technique: BreathingTechnique { selectedTechnique }
    private let groundingSteps = GroundingStep.fiveSteps

    enum PanicStage {
        case intro, grounding, breathingChoice, breathing, affirmation
    }

    var body: some View {
        ZStack {
            ZenGradient.panic.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Group {
                    switch stage {
                    case .intro:            introContent
                    case .grounding:        groundingContent
                    case .breathingChoice:  breathingChoiceContent
                    case .breathing:        breathingContent
                    case .affirmation:      affirmationContent
                    }
                }
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) { contentOpacity = 1 }
                }
                .onChange(of: stage) { _, newStage in
                    contentOpacity = 0
                    withAnimation(.easeIn(duration: 0.5)) { contentOpacity = 1 }
                    speakStageIntro(newStage)
                }
            }
        }
        .onAppear {
            audio.voiceName = voiceGender
            audio.startRain()
            Task {
                // Pre-generate ALL phrases in parallel so every transition is instant.
                // speakStageIntro is called AFTER prewarm completes so the intro
                // phrase plays immediately from cache — no network round-trip delay.
                let stageIntros = [
                    "You are safe. This feeling will pass. Let's work through it together, one step at a time.",
                    "Choose the breathing technique that feels right for you. All of them will help.",
                    "Great. Follow the circle and let your breath lead the way.",
                    "Well done. You moved through a difficult moment. That takes real courage. You are safe.",
                ]
                let groundingPhrases = groundingSteps.map { $0.voicePrompt }
                // Pre-warm phases for all three techniques so switching is instant
                let allBreathPhrases = (BreathingTechnique.all)
                    .flatMap { $0.phases.map { $0.voiceLabel } }
                await audio.prewarm(phrases: stageIntros + groundingPhrases + allBreathPhrases)
                // Cache is now warm — playback is instant, no choppiness
                speakStageIntro(.intro)
            }
        }
        .onChange(of: voiceGender) { _, newVoice in
            // 1. Set the new voice name BEFORE clearing the cache so fetchTTS
            //    picks up the new voice immediately.
            audio.voiceName = newVoice
            // 2. Bump cacheVersion + wipe stale files.  Any concurrent prewarm that was
            //    generating "nova" audio will see the version mismatch and discard its
            //    results, so it can never re-pollute the cache with the old voice.
            audio.clearCache()
            // 3. Kick off a fresh prewarm with the new voice so playback stays instant.
            Task {
                let stageIntros = [
                    "You are safe. This feeling will pass. Let's work through it together, one step at a time.",
                    "Choose the breathing technique that feels right for you. All of them will help.",
                    "Great. Follow the circle and let your breath lead the way.",
                    "Well done. You moved through a difficult moment. That takes real courage. You are safe.",
                ]
                let groundingPhrases = groundingSteps.map { $0.voicePrompt }
                let allBreathPhrases = (BreathingTechnique.all)
                    .flatMap { $0.phases.map { $0.voiceLabel } }
                await audio.prewarm(phrases: stageIntros + groundingPhrases + allBreathPhrases)
            }
        }
        .onDisappear {
            audio.teardown()
            breathTimer?.invalidate()
        }
    }

    // MARK: - Voice helpers

    private func speakStageIntro(_ s: PanicStage) {
        switch s {
        case .intro:
            audio.speak(
                "You are safe. This feeling will pass. Let's work through it together, one step at a time.",
                isPremium: subscriptionManager.isPremium
            )
        case .grounding:
            let step = groundingSteps[safe: groundingIndex]
            audio.speak(
                step?.voicePrompt ?? "Let's ground ourselves. Look around you.",
                isPremium: subscriptionManager.isPremium
            )
        case .breathingChoice:
            audio.speak(
                "Choose the breathing technique that feels right for you. All of them will help.",
                isPremium: subscriptionManager.isPremium
            )
        case .breathing:
            audio.speak(
                "Great. Follow the circle and let your breath lead the way.",
                isPremium: subscriptionManager.isPremium
            )
        case .affirmation:
            audio.speak(
                "Well done. You moved through a difficult moment. That takes real courage. You are safe.",
                isPremium: subscriptionManager.isPremium
            )
        }
    }

    private func speakBreathPhase(_ phase: BreathingTechnique.BreathPhase) {
        audio.speak(phase.voiceLabel, isPremium: subscriptionManager.isPremium)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                breathTimer?.invalidate()
                audio.teardown()
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("You're safe")
                    .font(ZenFont.heading(16))
                    .foregroundColor(.white.opacity(0.85))
                // Rain indicator
                HStack(spacing: 4) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.system(size: 10))
                    Text("Calm sounds on")
                        .font(ZenFont.caption(10))
                }
                .foregroundColor(.white.opacity(0.45))
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(stageIndex == i ? Color.white : Color.white.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    private var stageIndex: Int {
        switch stage {
        case .intro:                       return 0
        case .grounding:                   return 1
        case .breathingChoice, .breathing: return 2
        case .affirmation:                 return 3
        }
    }

    // MARK: - Intro

    private var introContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Reassurance header ──────────────────────────────────────
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.85, blue: 1.0),
                                     Color(red: 0.75, green: 0.60, blue: 0.95)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                Text("You are not in danger.")
                    .font(ZenFont.title(28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("This feeling will pass.\nLet's work through it together.")
                    .font(ZenFont.body(17))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.bottom, 36)

            // ── Intensity picker ────────────────────────────────────────
            VStack(spacing: 10) {
                Text("HOW INTENSE IS THIS?")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.8)

                HStack(spacing: 10) {
                    intensityButton(
                        symbol: "wind", label: "Mild",
                        sublabel: "Just anxious",
                        level: 1
                    )
                    intensityButton(
                        symbol: "cloud.rain.fill", label: "Moderate",
                        sublabel: "Pretty anxious",
                        level: 2
                    )
                    intensityButton(
                        symbol: "bolt.circle.fill", label: "Intense",
                        sublabel: "Panicking",
                        level: 3
                    )
                }
            }
            .padding(.bottom, 28)

            // ── Voice toggle (free for all users) ──────────────────────
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                    Text("Voice guidance")
                        .font(ZenFont.caption(12))
                }
                .foregroundColor(.white.opacity(0.55))

                HStack(spacing: 0) {
                    voiceToggleButton(label: "♀", voice: APIProxy.voiceFemale, selected: voiceGender == APIProxy.voiceFemale)
                    voiceToggleButton(label: "♂", voice: APIProxy.voiceMale,   selected: voiceGender == APIProxy.voiceMale)
                }
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
            .padding(.bottom, 24)

            Spacer()

            // ── Action buttons ──────────────────────────────────────────
            VStack(spacing: 12) {
                PanicActionButton(title: "I'm ready — let's begin", color: .white.opacity(0.25)) {
                    // Intense → skip grounding, go straight to breathing choice
                    stage = intensityLevel == 3 ? .breathingChoice : .grounding
                }
                Button {
                    stage = .breathingChoice
                } label: {
                    Text("Skip to breathing")
                        .font(ZenFont.caption(14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func intensityButton(symbol: String, label: String, sublabel: String, level: Int) -> some View {
        let isSelected = intensityLevel == level
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                intensityLevel = level
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(.white.opacity(0.90))
                Text(label)
                    .font(ZenFont.heading(13))
                    .foregroundColor(.white)
                Text(sublabel)
                    .font(ZenFont.caption(11))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? Color.white.opacity(0.28)
                          : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected
                                    ? Color.white.opacity(0.60)
                                    : Color.white.opacity(0.18),
                                    lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }

    // MARK: - Grounding

    private var groundingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            let step = groundingSteps[groundingIndex]

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(step.color.opacity(0.35))
                        .frame(width: 80, height: 80)
                    Text("\(step.number)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Image(systemName: step.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.9))

                Text(step.sense.uppercased())
                    .font(ZenFont.caption(13))
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(3)

                Text(step.prompt)
                    .font(ZenFont.heading(20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            Text("Take your time. When you're ready, tap next.")
                .font(ZenFont.caption(14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer()

            PanicActionButton(
                title: groundingIndex < groundingSteps.count - 1 ? "Next" : "Start Breathing",
                color: .white.opacity(0.25)
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if groundingIndex < groundingSteps.count - 1 {
                    groundingIndex += 1
                    let step = groundingSteps[safe: groundingIndex]
                    audio.speak(
                        step?.voicePrompt ?? "",
                        isPremium: subscriptionManager.isPremium
                    )
                } else {
                    stage = .breathingChoice
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Breathing Choice

    private var breathingChoiceContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "wind")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 4)

                Text("Choose your breath")
                    .font(ZenFont.title(24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("All techniques work. Trust your body.")
                    .font(ZenFont.body(15))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)

            // ── Technique cards ────────────────────────────────────────
            VStack(spacing: 12) {
                breathTechniqueCard(
                    technique: .box,
                    subtitle: "Steady & balanced",
                    detail:   "4 · 4 · 4 · 4"
                )
                breathTechniqueCard(
                    technique: .breathing478,
                    subtitle: "Deep relaxation",
                    detail:   "4 · 7 · 8"
                )
                breathTechniqueCard(
                    technique: .extendedExhale,
                    subtitle: "Quick anxiety relief",
                    detail:   "5 · 2 · 7"
                )
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func breathTechniqueCard(technique t: BreathingTechnique, subtitle: String, detail: String) -> some View {
        let isSelected = selectedTechnique.name == t.name
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedTechnique = t
            breathPhase = 0; breathScale = 0.7; breathLabel = "Ready"; isBreathingActive = false; round = 1
            stage = .breathing
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.28 : 0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: t.sfSymbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.name)
                        .font(ZenFont.heading(16))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(ZenFont.caption(13))
                        .foregroundColor(.white.opacity(0.70))
                }

                Spacer()

                // Ratio badge
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.70))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected
                          ? Color.white.opacity(0.22)
                          : Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected
                                    ? Color.white.opacity(0.50)
                                    : Color.white.opacity(0.18),
                                    lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Breathing

    private var breathingContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text(technique.name)
                    .font(ZenFont.heading(20))
                    .foregroundColor(.white)
                Text("Round \(round) of \(technique.totalRounds)")
                    .font(ZenFont.caption(14))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.top, 8)

            Spacer()

            ZStack {
                ForEach(0..<2) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: CGFloat(200 + i * 40) * breathScale)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.12)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: technique.phases[safe: breathPhase]?.duration ?? 4), value: breathScale)

                VStack(spacing: 6) {
                    Text(breathLabel)
                        .font(ZenFont.title(22))
                        .foregroundColor(.white)
                    if phaseSecondsLeft > 0 {
                        Text("\(phaseSecondsLeft)")
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .frame(height: 260)

            Text(technique.phases[safe: breathPhase]?.instruction ?? "")
                .font(ZenFont.body(16))
                .foregroundColor(.white.opacity(0.80))
                .multilineTextAlignment(.center)
                .frame(height: 44)

            Spacer()

            if !isBreathingActive {
                VStack(spacing: 12) {
                    PanicActionButton(title: "Begin Breathing", color: .white.opacity(0.25)) {
                        startBreathing()
                    }
                    Button {
                        stage = .breathingChoice
                    } label: {
                        Text("Change technique")
                            .font(ZenFont.caption(13))
                            .foregroundColor(.white.opacity(0.50))
                    }
                }
            } else {
                Button {
                    breathTimer?.invalidate()
                    audio.stopSpeaking()
                    isBreathingActive = false
                    stage = .affirmation
                } label: {
                    Text("I feel calmer — continue")
                        .font(ZenFont.caption(14))
                        .foregroundColor(.white.opacity(0.65))
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Affirmation

    private var affirmationContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Celebration header ──────────────────────────────────────
            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.94, blue: 0.55),
                                     Color(red: 0.96, green: 0.76, blue: 0.30)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                Text("Well done.")
                    .font(ZenFont.title(32))
                    .foregroundColor(.white)

                Text("You moved through a moment of difficulty.\nThat takes real courage.")
                    .font(ZenFont.body(17))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.bottom, 24)

            // ── Affirmation card ────────────────────────────────────────
            affirmationCard
                .padding(.bottom, 28)

            // ── Post-session feel rating ────────────────────────────────
            VStack(spacing: 12) {
                Text("HOW DO YOU FEEL NOW?")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.8)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { value in
                        let symbols = [
                            "cloud.bolt.fill",
                            "cloud.rain.fill",
                            "cloud.fill",
                            "sun.haze.fill",
                            "sun.max.fill"
                        ]
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                postRating = value
                            }
                            saveEpisode(rating: value)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: symbols[value - 1])
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.white.opacity(postRating == value ? 1.0 : 0.55))
                                Circle()
                                    .fill(postRating == value
                                          ? Color.white
                                          : Color.white.opacity(0.25))
                                    .frame(width: 8, height: 8)
                            }
                            .frame(maxWidth: .infinity)
                            .scaleEffect(postRating == value ? 1.15 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: postRating)
                    }
                }

                if let rating = postRating {
                    let messages = ["Hang in there.", "Getting there.", "Good progress.", "Great work!", "Amazing!"]
                    Text(messages[rating - 1])
                        .font(ZenFont.body(14))
                        .foregroundColor(.white.opacity(0.80))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.bottom, 28)

            // ── Journal nudge ───────────────────────────────────────────
            journalNudge
                .padding(.bottom, 8)

            Spacer()

            // ── Action buttons ──────────────────────────────────────────
            VStack(spacing: 12) {
                PanicActionButton(title: "Return to Everbloom", color: .white.opacity(0.25)) {
                    breathTimer?.invalidate()
                    audio.teardown()
                    isPresented = false
                }
                Button {
                    resetFlow()
                } label: {
                    Text("Go through it again")
                        .font(ZenFont.caption(14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Journal Nudge

    private var journalNudge: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            journalNudgeTapped = true
            // Store draft text on JournalStore — ContentView will open NewEntryView
            let intensityLabel = ["", "Mild", "Moderate", "Intense"][intensityLevel]
            let ratingLabel    = postRating.map { ["😟", "😕", "😐", "🙂", "😊"][$0 - 1] } ?? ""
            let prompt = "I just went through a \(intensityLabel.lowercased()) anxiety moment using \(selectedTechnique.name). \(ratingLabel.isEmpty ? "" : "Afterwards I felt \(ratingLabel). ")What was happening, and how do I feel now?"
            journalStore.panicSessionDraft = prompt
            breathTimer?.invalidate()
            audio.teardown()
            isPresented = false
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Write about it")
                        .font(ZenFont.heading(14))
                        .foregroundColor(.white)
                    Text("Journaling helps process what just happened")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.white.opacity(0.60))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(journalNudgeTapped ? 0.20 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func saveEpisode(rating: Int) {
        struct PanicEpisode: Codable {
            let date: Date
            let technique: String
            let intensity: Int
            let postRating: Int
        }
        var existing: [PanicEpisode] = (try? JSONDecoder().decode([PanicEpisode].self,
            from: Data(episodesJSON.utf8))) ?? []
        existing.append(PanicEpisode(
            date: Date(),
            technique: selectedTechnique.name,
            intensity: intensityLevel,
            postRating: rating
        ))
        if let encoded = try? JSONEncoder().encode(existing),
           let str = String(data: encoded, encoding: .utf8) {
            episodesJSON = str
        }
    }

    private func resetFlow() {
        stage = .grounding
        groundingIndex = 0
        breathPhase = 0
        breathScale = 0.7
        breathLabel = "Ready"
        isBreathingActive = false
        round = 1
        postRating = nil
        selectedTechnique = .box
    }

    private var affirmationCard: some View {
        let affirmations = [
            "This too shall pass.",
            "You are stronger than your anxiety.",
            "Your breath is always with you.",
            "You have survived every difficult moment so far.",
            "It is okay to feel. You are safe.",
            "You are not your thoughts.",
            "Right now, in this moment, you are okay.",
            "Courage isn't the absence of fear — it's breathing through it.",
            "Your nervous system is calming. The storm is passing.",
            "You showed up for yourself. That matters.",
            "Being gentle with yourself is a form of strength.",
            "You have done this before. You will do it again.",
            "Anxiety lies. You are safe.",
        ]
        let text = affirmations.randomElement() ?? affirmations[0]

        return Text("\"" + text + "\"")
            .font(ZenFont.heading(17))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .italic()
            .padding(20)
            .background(Color.white.opacity(0.14))
            .cornerRadius(16)
    }

    // MARK: - Breathing Logic

    private func startBreathing() {
        isBreathingActive = true
        breathPhase = 0
        round = 1
        runPhase()
    }

    private func runPhase() {
        guard breathPhase < technique.phases.count else {
            if round < technique.totalRounds {
                round += 1
                breathPhase = 0
                runPhase()
            } else {
                isBreathingActive = false
                stage = .affirmation
            }
            return
        }

        let phase = technique.phases[breathPhase]
        breathLabel = phase.label
        phaseSecondsLeft = Int(phase.duration)

        withAnimation(.easeInOut(duration: phase.duration)) {
            breathScale = phase.scale
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Speak phase label via TTS
        speakBreathPhase(phase)

        breathTimer?.invalidate()
        var elapsed = 0
        breathTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            elapsed += 1
            phaseSecondsLeft = max(0, Int(phase.duration) - elapsed)

            if elapsed >= Int(phase.duration) {
                timer.invalidate()
                breathPhase += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    runPhase()
                }
            }
        }
    }
}

// MARK: - Helpers

// MARK: - Voice Toggle

extension PanicButtonView {
    func voiceToggleButton(label: String, voice: String, selected: Bool) -> some View {
        Button {
            voiceGender = voice
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .white.opacity(0.45))
                .frame(width: 34, height: 26)
                .background(selected ? Color.white.opacity(0.22) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct PanicActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ZenFont.heading(17))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PanicButtonStyle())
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    PanicButtonView(isPresented: .constant(true))
        .environmentObject(SubscriptionManager())
}
