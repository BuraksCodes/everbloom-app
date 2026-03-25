// AudioManager.swift
// Everbloom — Ambient sound playback manager
//
// Uses AVPlayerLooper (AVQueuePlayer + AVPlayerLooper) for TRUE gapless looping —
// no pop or gap at the loop point. Falls back to SoundEngine synthesis while the
// real file is downloading, then seamlessly switches once cached.
//
// Resilient to audio-session interruptions (phone calls, Siri, notifications)
// and route changes (headphones in/out).

import Foundation
import AVFoundation
import Combine

class AudioManager: ObservableObject {

    @Published var currentSound: SoundOption? = nil
    @Published var isPlaying:    Bool  = false
    @Published var isMuted:      Bool  = false { didSet { applyVolume() } }
    @Published var volume:       Float = 0.75  { didSet { applyVolume() } }
    @Published var fadeOutMinutes: Double = 0

    // ── Gapless loop player ──
    // AVPlayerLooper pre-queues the next iteration before the current one ends,
    // eliminating the gap you'd normally hear with AVAudioPlayer loop callbacks.
    private var queuePlayer:  AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    // ── Synthesized fallback while real file downloads ──
    private let engine = SoundEngine()

    private var fadeTimer: Timer?

    // MARK: - Init

    init() {
        setupAudioSession()
        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[AudioManager] Session setup error: \(error)")
            #endif
        }
    }

    // MARK: - Interruption / Route-change Resilience

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        // iOS can reset the media server (e.g. after memory pressure or a crash).
        // When this happens all AVPlayer instances become invalid — rebuild the player
        // so the sound resumes automatically without the user having to re-tap.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    @objc private func handleMediaServicesReset() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let sound = self.currentSound, self.isPlaying else { return }
            // Re-configure session — it was also reset
            self.setupAudioSession()
            // Rebuild the player from the cached file (or synthesiser fallback)
            if let url = SoundDownloader.shared.cachedURL(for: sound.fileName) {
                self.playGapless(from: url)
            } else {
                self.engine.play(fileName: sound.fileName)
                self.engine.volume = self.isMuted ? 0 : self.volume
            }
        }
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info      = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type      = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if type == .ended {
                let opts = AVAudioSession.InterruptionOptions(
                    rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                )
                if opts.contains(.shouldResume), self.isPlaying {
                    self.queuePlayer?.play()
                }
            }
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard let info      = note.userInfo,
              let reasonVal = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason    = AVAudioSession.RouteChangeReason(rawValue: reasonVal)
        else { return }

        // Stop when headphones are pulled out (mirrors iOS Music app behaviour)
        if reason == .oldDeviceUnavailable {
            DispatchQueue.main.async { [weak self] in self?.pause() }
        }
    }

    // MARK: - Playback

    func play(_ sound: SoundOption) {
        // Tap same sound again → toggle pause
        if let current = currentSound, current.id == sound.id, isPlaying {
            pause(); return
        }

        stopFadeTimer()
        isMuted      = false
        currentSound = sound
        isPlaying    = true

        if let cachedURL = SoundDownloader.shared.cachedURL(for: sound.fileName) {
            playGapless(from: cachedURL)
        } else {
            // Synthesized placeholder while the real file downloads
            engine.play(fileName: sound.fileName)
            engine.volume = volume

            Task { [weak self] in
                guard let self else { return }
                await SoundDownloader.shared.download(sound.fileName)
                await MainActor.run {
                    guard
                        self.currentSound?.fileName == sound.fileName,
                        self.isPlaying,
                        let url = SoundDownloader.shared.cachedURL(for: sound.fileName)
                    else { return }
                    self.engine.stop()
                    self.playGapless(from: url)
                }
            }
        }

        scheduleFadeOut()
    }

    /// True gapless loop using AVQueuePlayer + AVPlayerLooper.
    /// AVPlayerLooper pre-queues the next copy before the current one finishes,
    /// so there is zero audible gap or click at the boundary.
    private func playGapless(from url: URL) {
        engine.stop()
        queuePlayer?.pause()
        playerLooper = nil
        queuePlayer  = nil

        let item   = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.volume = isMuted ? 0 : volume

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer  = player
        player.play()
    }

    func pause() {
        queuePlayer?.pause()
        engine.stop()
        isPlaying = false
    }

    func resume() {
        guard let sound = currentSound else { return }
        isPlaying = true
        if let player = queuePlayer {
            player.play()
        } else if let url = SoundDownloader.shared.cachedURL(for: sound.fileName) {
            playGapless(from: url)
        } else {
            engine.play(fileName: sound.fileName)
            engine.volume = isMuted ? 0 : volume
        }
    }

    func stop() {
        stopFadeTimer()
        queuePlayer?.pause()
        playerLooper = nil
        queuePlayer  = nil
        engine.stop()
        isPlaying    = false
        isMuted      = false
        currentSound = nil
    }

    func toggleMute() { isMuted.toggle() }

    func isCurrentlyPlaying(_ sound: SoundOption) -> Bool {
        currentSound?.id == sound.id && isPlaying
    }

    // MARK: - Volume

    private func applyVolume() {
        let v = isMuted ? Float(0) : volume
        queuePlayer?.volume = v
        engine.volume       = v
    }

    // MARK: - Fade-out Timer

    private func scheduleFadeOut() {
        stopFadeTimer()
        guard fadeOutMinutes > 0 else { return }
        let delay = max(1.0, (fadeOutMinutes * 60) - 30)
        fadeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.beginFade(duration: 30)
        }
    }

    private func beginFade(duration: TimeInterval) {
        let steps    = 30
        let interval = duration / Double(steps)
        let startVol = queuePlayer?.volume ?? engine.volume
        var step     = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let v = max(0, startVol * (1 - Float(step) / Float(steps)))
            self.queuePlayer?.volume = v
            self.engine.volume       = v
            if step >= steps {
                timer.invalidate()
                self.stop()
                self.volume = startVol   // restore for next session
            }
        }
    }

    private func stopFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
}
