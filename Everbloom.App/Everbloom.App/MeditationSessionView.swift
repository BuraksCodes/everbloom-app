// MeditationSessionView.swift
// Everbloom — Immersive guided meditation session player
//
// Audio design:
//   • MeditationVoiceCoach uses AVSpeechSynthesizer to deliver a spoken intro
//     and a gentle spoken cue whenever the on-screen guidance text changes.
//   • A looping AVAudioPlayer handles the per-session ambient soundscape.
//   • Both respect the play/pause state and are torn down on dismiss.

import SwiftUI
import AVFoundation
import Combine

// MARK: - Voice Coach
// Uses ElevenLabs TTS via the Cloudflare Worker proxy (same as PanicButtonView).
// All meditation steps are pre-warmed on session start so each cue plays instantly
// without any network lag. Falls back to the best on-device iOS voice if offline.

@MainActor
private final class MeditationVoiceCoach: NSObject {

    // TTS is routed through APIProxy → Cloudflare Worker. No key in this binary.

    // phrase → cached temp-file URL
    private var phraseCache: [String: URL] = [:]
    private var ttsPlayer:   AVAudioPlayer?

    // On-device fallback (used when offline)
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Pre-warm

    /// Fetch all session step texts in parallel before they're needed so
    /// every cue plays with zero latency. Call once on .onAppear.
    func prewarm(phrases: [String], voice: String) async {
        let toFetch = phrases.filter { phraseCache[clean($0)] == nil }
        guard !toFetch.isEmpty else { return }
        var results: [(String, URL)] = []
        await withTaskGroup(of: (String, URL?).self) { group in
            for phrase in toFetch {
                let cleaned = clean(phrase)
                group.addTask {
                    // Route through the Cloudflare Worker proxy — key never in binary
                    let url = await APIProxy.fetchTTS(phrase: cleaned, voice: voice, speed: 0.82)
                    return (cleaned, url)
                }
            }
            for await (phrase, maybeURL) in group {
                if let url = maybeURL { results.append((phrase, url)) }
            }
        }
        for (phrase, url) in results { phraseCache[phrase] = url }
    }

    // MARK: - Speak

    /// Play a guidance cue — instantly if pre-warmed, async fetch otherwise.
    func speak(_ text: String, voice: String) {
        let cleaned = clean(text)
        guard !cleaned.isEmpty else { return }
        ttsPlayer?.stop()
        synthesizer.stopSpeaking(at: .word)

        if let cached = phraseCache[cleaned] {
            playFile(cached)
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let url = await APIProxy.fetchTTS(phrase: cleaned, voice: voice, speed: 0.82) {
                    self.phraseCache[cleaned] = url
                    self.playFile(url)
                } else {
                    self.fallbackSpeak(cleaned)
                }
            }
        }
    }

    // MARK: - Playback control

    func stop() {
        ttsPlayer?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }

    func pause() {
        ttsPlayer?.pause()
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        ttsPlayer?.play()
        synthesizer.continueSpeaking()
    }

    // MARK: - Private helpers

    private func playFile(_ url: URL) {
        do {
            // Ensure audio session is active before playing on real device
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            ttsPlayer = try AVAudioPlayer(contentsOf: url)
            ttsPlayer?.volume = voiceVolume
            ttsPlayer?.prepareToPlay()
            ttsPlayer?.play()
        } catch {
            #if DEBUG
            print("[MeditationVoiceCoach] Playback error: \(error)")
            #endif
        }
    }

    func setVoiceVolume(_ v: Float) {
        voiceVolume = v
        ttsPlayer?.volume = v
    }

    private var voiceVolume: Float = 1.0

    /// Best available on-device voice — used when network unavailable.
    private func fallbackSpeak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let all = AVSpeechSynthesisVoice.speechVoices()
        utterance.voice = all.first(where: { $0.language.hasPrefix("en") && $0.quality == .premium })
                       ?? all.first(where: { $0.language.hasPrefix("en") && $0.quality == .enhanced })
                       ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate               = 0.40
        utterance.pitchMultiplier    = 0.93
        utterance.volume             = 0.92
        utterance.preUtteranceDelay  = 0.60
        synthesizer.speak(utterance)
    }

    /// Strip emojis and tidy punctuation so TTS sounds natural.
    private func clean(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "…", with: ",")
            .replacingOccurrences(of: "🌸", with: "")
            .replacingOccurrences(of: "🌤", with: "")
            .replacingOccurrences(of: "🌿", with: "")
            .replacingOccurrences(of: "🎯", with: "")
            .replacingOccurrences(of: "💗", with: "")
            .replacingOccurrences(of: "✨", with: "")
            .replacingOccurrences(of: "🌙", with: "")
            .replacingOccurrences(of: "🌊", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Session View

struct MeditationSessionView: View {

    let session: MeditationSession
    @Environment(\.dismiss) private var dismiss

    // MARK: Timer state
    @State private var elapsedSeconds: Int    = 0
    @State private var isPlaying:      Bool   = true
    @State private var isComplete:     Bool   = false
    @State private var sessionStart:   Date   = Date()   // for HealthKit duration

    // MARK: Animation state
    @State private var orbScale:        CGFloat = 1.0
    @State private var appeared:        Bool    = false
    @State private var guidanceOpacity: Double  = 1.0

    // MARK: Guidance tracking
    @State private var currentStepID: UUID = UUID()

    // MARK: Audio
    @State private var voiceCoach:     MeditationVoiceCoach = MeditationVoiceCoach()
    @State private var ambientPlayer:  AVAudioPlayer?       = nil
    @State private var isSoundMuted:   Bool                 = false
    @State private var isVoiceMuted:   Bool                 = false
    @State private var voiceVolume:    Float                = 1.0
    @State private var ambientVolume:  Float                = 0.32
    @State private var showingVolumes: Bool                 = false
    /// Shares the same ElevenLabs voice ID preference as PanicButtonView.
    @AppStorage("panicVoiceGender") private var voiceGender: String = APIProxy.voiceFemale

    // MARK: Timer
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Computed

    private var progress: Double {
        guard session.totalSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(session.totalSeconds), 1.0)
    }

    private var timeRemainingLabel: String {
        let remaining = max(session.totalSeconds - elapsedSeconds, 0)
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private var currentStep: MeditationStep {
        session.currentStep(at: elapsedSeconds)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // ── Full-screen gradient background ──────────────────────────
            LinearGradient(
                colors: session.theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle floating blobs
            ambientBlobs

            VStack(spacing: 0) {
                // ── Top bar ───────────────────────────────────────────────
                topBar
                    .padding(.top, 56)
                    .padding(.horizontal, 24)

                // ── Volume panel (shown when slider button tapped) ─────────
                if showingVolumes {
                    volumePanel
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                // ── Central orb + progress ring ───────────────────────────
                orbArea
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.72)

                Spacer()

                // ── Guidance text ─────────────────────────────────────────
                guidanceText
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // ── Controls ──────────────────────────────────────────────
                if !isComplete {
                    controlsBar
                        .padding(.horizontal, 40)
                        .padding(.bottom, 50)
                }
            }

            // ── Completion overlay ────────────────────────────────────────
            if isComplete {
                completionOverlay
            }
        }
        .onAppear {
            currentStepID = session.steps[0].id
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.15)) {
                appeared = true
            }
            startOrbPulse()
            startAmbient()
            // Pre-warm all step texts in the background so cues play instantly
            let allTexts = session.steps.map(\.text)
            let voice    = voiceGender
            Task {
                await voiceCoach.prewarm(phrases: allTexts, voice: voice)
            }
            // Speak the intro after a short beat so the orb animation settles first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard isPlaying, !isVoiceMuted else { return }
                voiceCoach.speak(session.steps[0].text, voice: voiceGender)
            }
        }
        .onDisappear {
            stopAllAudio()
        }
        .onReceive(ticker) { _ in
            guard isPlaying && !isComplete else { return }
            let newElapsed = elapsedSeconds + 1

            // Detect step change → crossfade text + speak new cue
            let newStep = session.currentStep(at: newElapsed)
            if newStep.id != currentStep.id {
                crossfadeGuidance(to: newStep)
                // Delay speech slightly so it overlaps less with the visual fade
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard isPlaying, !isVoiceMuted else { return }
                    voiceCoach.speak(newStep.text, voice: voiceGender)
                }
            }

            elapsedSeconds = newElapsed

            if elapsedSeconds >= session.totalSeconds {
                finishSession()
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                ambientPlayer?.play()
                voiceCoach.resume()
            } else {
                ambientPlayer?.pause()
                voiceCoach.pause()
            }
        }
        .onChange(of: isSoundMuted) { _, muted in
            ambientPlayer?.volume = muted ? 0.0 : ambientVolume
        }
        .onChange(of: isVoiceMuted) { _, muted in
            if muted { voiceCoach.stop() }
        }
        .onChange(of: voiceVolume) { _, v in
            voiceCoach.setVoiceVolume(v)
        }
        .onChange(of: ambientVolume) { _, v in
            if !isSoundMuted { ambientPlayer?.volume = v }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Ambient Blobs

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 300)
                .blur(radius: 60)
                .offset(x: -120, y: -250)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 240)
                .blur(radius: 50)
                .offset(x: 130, y: 280)
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Title
            VStack(spacing: 2) {
                Text(session.title)
                    .font(ZenFont.heading(16))
                    .foregroundColor(.white)
                Text(session.category.rawValue)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            // Voice + Sound controls
            HStack(spacing: 10) {
                // Voice guidance toggle
                audioToggleButton(
                    icon: isVoiceMuted ? "mic.slash.fill" : "mic.fill",
                    active: !isVoiceMuted
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isVoiceMuted.toggle()
                }

                // Ambient sound toggle
                audioToggleButton(
                    icon: isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    active: !isSoundMuted
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isSoundMuted.toggle()
                }

                // Volume sliders button
                audioToggleButton(icon: "slider.horizontal.3", active: showingVolumes) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showingVolumes.toggle()
                    }
                }
            }
        }
    }

    // MARK: - Volume Panel

    private var volumePanel: some View {
        VStack(spacing: 14) {
            // Voice volume
            HStack(spacing: 12) {
                Image(systemName: isVoiceMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.70))
                    .frame(width: 20)
                Slider(value: $voiceVolume, in: 0...1)
                    .tint(.white.opacity(0.80))
                    .disabled(isVoiceMuted)
                    .opacity(isVoiceMuted ? 0.35 : 1.0)
                Text("Voice")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 36, alignment: .trailing)
            }

            // Ambient volume
            HStack(spacing: 12) {
                Image(systemName: isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.70))
                    .frame(width: 20)
                Slider(value: $ambientVolume, in: 0...1)
                    .tint(.white.opacity(0.80))
                    .disabled(isSoundMuted)
                    .opacity(isSoundMuted ? 0.35 : 1.0)
                Text("Ambient")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Reusable small circular toggle button for the top bar.
    private func audioToggleButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(active ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(active ? .white : .white.opacity(0.40))
            }
        }
    }

    // MARK: - Orb Area

    private var orbArea: some View {
        ZStack {
            // ── Outer progress ring ───────────────────────────────────────
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 240, height: 240)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.white.opacity(0.70),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }

            // ── Glow rings ────────────────────────────────────────────────
            ForEach([0, 1, 2], id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.10 - Double(i) * 0.03), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100 + CGFloat(i * 22)
                        )
                    )
                    .frame(width: CGFloat(200 + i * 44), height: CGFloat(200 + i * 44))
                    .scaleEffect(orbScale)
            }

            // ── Main orb ──────────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.06)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(orbScale)
                    .blur(radius: 1)
                Image(systemName: session.sfSymbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.white.opacity(0.82))
                    .scaleEffect(orbScale * 0.95 + 0.05)
            }

            // ── Time remaining ────────────────────────────────────────────
            Text(timeRemainingLabel)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .offset(y: 132)
        }
        .frame(width: 240, height: 300)
    }

    // MARK: - Guidance Text

    private var guidanceText: some View {
        Text(currentStep.text)
            .font(ZenFont.body(18))
            .foregroundColor(.white.opacity(0.92))
            .multilineTextAlignment(.center)
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(guidanceOpacity)
            .id(currentStepID)
            .transition(.opacity)
            .frame(minHeight: 80)
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: 52) {
            // Restart
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                restartSession()
            } label: {
                controlButton(icon: "arrow.counterclockwise", size: 20, bgOpacity: 0.18)
            }

            // Play / Pause
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    isPlaying.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 68, height: 68)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 2)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
            }

            // Skip 30 s
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                skipForward()
            } label: {
                controlButton(icon: "goforward.30", size: 20, bgOpacity: 0.18)
            }
        }
    }

    private func controlButton(icon: String, size: CGFloat, bgOpacity: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(bgOpacity))
                .frame(width: 46, height: 46)
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                }

                VStack(spacing: 10) {
                    Text("Well done")
                        .font(ZenFont.title(28))
                        .foregroundColor(.white)
                    Text("You completed \(session.durationMinutes) minutes of mindful practice.")
                        .font(ZenFont.body(16))
                        .foregroundColor(.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button { dismiss() } label: {
                    Text("Finish")
                        .font(ZenFont.heading(18))
                        .foregroundColor(session.theme.gradientColors[0])
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 40)

                Button { restartSession() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Meditate Again")
                    }
                    .font(ZenFont.body(15))
                    .foregroundColor(.white.opacity(0.80))
                }
            }
            .padding(32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Helpers

    private func startOrbPulse() {
        withAnimation(
            .easeInOut(duration: 4.0)
            .repeatForever(autoreverses: true)
        ) {
            orbScale = 1.10
        }
    }

    private func startAmbient() {
        guard
            let fileName = session.ambientSoundFile,
            let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
        else { return }   // gracefully silent if file isn't bundled yet

        do {
            ambientPlayer = try AVAudioPlayer(contentsOf: url)
            ambientPlayer?.numberOfLoops = -1       // infinite
            ambientPlayer?.volume        = 0.0      // start silent for fade-in
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
            // Gentle fade-in over 3 seconds so it doesn't startle
            fadeAmbientVolume(to: ambientVolume, duration: 3.0)
        } catch {
            #if DEBUG
            print("[MeditationSessionView] Ambient audio error: \(error)")
            #endif
        }
    }

    /// Linearly ramp the ambient player's volume over `duration` seconds.
    private func fadeAmbientVolume(to target: Float, duration: TimeInterval) {
        guard let player = ambientPlayer else { return }
        let steps    = 30
        let interval = duration / Double(steps)
        let delta    = (target - player.volume) / Float(steps)
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                guard let p = ambientPlayer, p.isPlaying else { return }
                p.volume = max(0, min(1, p.volume + delta))
            }
        }
    }

    private func stopAllAudio() {
        voiceCoach.stop()
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    private func crossfadeGuidance(to step: MeditationStep) {
        withAnimation(.easeOut(duration: 0.35)) {
            guidanceOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            currentStepID = step.id
            withAnimation(.easeIn(duration: 0.45)) {
                guidanceOpacity = 1
            }
        }
    }

    private func skipForward() {
        let newElapsed = min(elapsedSeconds + 30, session.totalSeconds - 1)
        let newStep    = session.currentStep(at: newElapsed)
        if newStep.id != currentStep.id {
            crossfadeGuidance(to: newStep)
        }
        elapsedSeconds = newElapsed
    }

    private func restartSession() {
        voiceCoach.stop()
        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = false
        }
        elapsedSeconds = 0
        isPlaying      = true
        currentStepID  = session.steps[0].id
        withAnimation(.easeIn(duration: 0.4)) {
            guidanceOpacity = 1
        }
        // Restart ambient and re-speak the intro
        if let player = ambientPlayer {
            player.currentTime = 0
            player.play()
        } else {
            startAmbient()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard isPlaying, !isVoiceMuted else { return }
            voiceCoach.speak(session.steps[0].text, voice: voiceGender)
        }
    }

    private func finishSession() {
        isPlaying = false
        voiceCoach.stop()
        // Fade ambient out gently before showing the completion overlay
        fadeAmbientVolume(to: 0.0, duration: 2.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            ambientPlayer?.stop()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.80).delay(0.4)) {
            isComplete = true
        }
        // Log completed session to Apple Health
        let end = Date()
        Task {
            await HealthKitManager.shared.logMindfulSession(
                start: sessionStart, end: end, source: "Meditation"
            )
        }
    }
}

#Preview {
    MeditationSessionView(session: MeditationLibrary.sessions[0])
}
