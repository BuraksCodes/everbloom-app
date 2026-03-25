// SoundEngine.swift
// Everbloom — High-quality real-time ambient sound synthesis via AVAudioEngine.
// No audio files required. All sounds are generated sample-by-sample using
// psychoacoustically tuned algorithms.
//
// Sound design approach per track:
//   Rain      — pink noise → lowpass → dual-rate amplitude envelope (gusts + drops)
//   Forest    — pink noise → bandpass → ultra-slow breeze swell
//   Ocean     — brown noise → deep lowpass → three overlapping wave oscillators
//   White Noise— flat spectrum, no modulation (focus/masking)
//   Stream    — pink noise + faster babble modulation (multi-rate)
//   Wind Bells — pink noise bed + 5 bell voices with exponential decay & random retrigger

import AVFoundation
import Foundation

// MARK: - Sound Profile

private struct SoundProfile {
    let highpassCutoff: Float
    let lowpassCutoff:  Float
    let gain:           Float

    // Noise character (0 = white, 1 = fully brown)
    let pinkWeight:  Float
    let brownWeight: Float

    // Up to 3 amplitude modulation layers (freq Hz, depth 0-1)
    let mod1: (freq: Float, depth: Float)
    let mod2: (freq: Float, depth: Float)
    let mod3: (freq: Float, depth: Float)

    // Bell voices — only used for Wind Bells
    // (frequency Hz, decay seconds, retrigger interval seconds)
    let bells: [(freq: Float, decay: Float, interval: Float)]

    // Reverb — transforms flat synthesis into a real acoustic space.
    // Without reverb, pink noise sounds like static from a speaker.
    // With the right preset it sounds like you're actually there.
    let reverbPreset: AVAudioUnitReverbPreset
    let reverbMix:    Float   // 0 = dry, 100 = fully wet
}

// MARK: - Sound Engine

final class SoundEngine {

    private var engine      = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var eqNode:     AVAudioUnitEQ?
    private var reverbNode: AVAudioUnitReverb?
    private var mixer       = AVAudioMixerNode()

    private(set) var isRunning = false

    var volume: Float = 0.75 {
        didSet { mixer.outputVolume = max(0, min(1, volume)) }
    }

    init() {
        // Configure the shared audio session up front so that:
        // 1. Sound plays even when the ringer/silent switch is ON
        // 2. AVSpeechSynthesizer and SoundEngine share the same session cleanly
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default,
                                    options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[SoundEngine] Audio session setup failed: \(error)")
            #endif
        }
    }

    // MARK: - Profiles
    // All frequencies and gains are tuned so the sounds sit at a comfortable
    // background level and avoid the harsh, synthetic quality of raw white noise.

    private static let profiles: [String: SoundProfile] = [

        // ── Rain ──────────────────────────────────────────────────────────────
        // Reverb: mediumRoom — sounds like rain heard from inside, close and enveloping.
        "rain": SoundProfile(
            highpassCutoff: 180,
            lowpassCutoff:  4_200,
            gain:           0.52,
            pinkWeight:     0.80,
            brownWeight:    0.20,
            mod1: (freq: 0.06,  depth: 0.22),
            mod2: (freq: 0.18,  depth: 0.18),
            mod3: (freq: 0.55,  depth: 0.10),
            bells: [],
            reverbPreset: .mediumRoom,
            reverbMix: 28
        ),

        // ── Forest ────────────────────────────────────────────────────────────
        // Reverb: largeChamber — wide outdoor space with trees surrounding you.
        "forest": SoundProfile(
            highpassCutoff: 380,
            lowpassCutoff:  8_500,
            gain:           0.44,
            pinkWeight:     0.70,
            brownWeight:    0.10,
            mod1: (freq: 0.03,  depth: 0.14),
            mod2: (freq: 0.11,  depth: 0.08),
            mod3: (freq: 0.00,  depth: 0.00),
            bells: [],
            reverbPreset: .largeChamber,
            reverbMix: 38
        ),

        // ── Ocean ─────────────────────────────────────────────────────────────
        // Reverb: plate — adds the vast open resonance of crashing waves on a beach.
        "ocean": SoundProfile(
            highpassCutoff:  25,
            lowpassCutoff:  720,
            gain:           0.70,
            pinkWeight:     0.30,
            brownWeight:    0.70,
            mod1: (freq: 0.09,  depth: 0.65),
            mod2: (freq: 0.13,  depth: 0.35),
            mod3: (freq: 0.19,  depth: 0.20),
            bells: [],
            reverbPreset: .plate,
            reverbMix: 42
        ),

        // ── White Noise ───────────────────────────────────────────────────────
        // Minimal reverb — pure masking noise should stay flat and clinical.
        "whitenoise": SoundProfile(
            highpassCutoff:   20,
            lowpassCutoff:  18_000,
            gain:           0.38,
            pinkWeight:     0.30,
            brownWeight:    0.00,
            mod1: (freq: 0.00, depth: 0.00),
            mod2: (freq: 0.00, depth: 0.00),
            mod3: (freq: 0.00, depth: 0.00),
            bells: [],
            reverbPreset: .smallRoom,
            reverbMix: 6
        ),

        // ── Stream ────────────────────────────────────────────────────────────
        // Reverb: mediumRoom — babbling brook with rock/stone acoustic reflection.
        "stream": SoundProfile(
            highpassCutoff: 300,
            lowpassCutoff:  6_000,
            gain:           0.46,
            pinkWeight:     0.65,
            brownWeight:    0.15,
            mod1: (freq: 0.35,  depth: 0.26),
            mod2: (freq: 0.72,  depth: 0.14),
            mod3: (freq: 0.08,  depth: 0.10),
            bells: [],
            reverbPreset: .mediumRoom,
            reverbMix: 32
        ),

        // ── Wind Bells ────────────────────────────────────────────────────────
        // Reverb: cathedral — the long tail makes bell notes ring and decay naturally
        // just like real metal chimes in open air.
        "windbells": SoundProfile(
            highpassCutoff: 250,
            lowpassCutoff:  11_000,
            gain:           0.36,
            pinkWeight:     0.40,
            brownWeight:    0.05,
            mod1: (freq: 0.10, depth: 0.30),
            mod2: (freq: 0.00, depth: 0.00),
            mod3: (freq: 0.00, depth: 0.00),
            bells: [
                (freq: 440.0,  decay: 2.8, interval: 1.4),
                (freq: 528.0,  decay: 3.2, interval: 1.9),
                (freq: 660.0,  decay: 2.5, interval: 2.3),
                (freq: 792.0,  decay: 3.5, interval: 1.7),
                (freq: 880.0,  decay: 2.0, interval: 2.8),
            ],
            reverbPreset: .cathedral,
            reverbMix: 55
        ),
    ]

    // MARK: - Public API

    func play(fileName: String) {
        guard let profile = Self.profiles[fileName] else { return }
        stop()
        buildAndStart(profile: profile)
    }

    func stop() {
        engine.stop()
        engine     = AVAudioEngine()
        mixer      = AVAudioMixerNode()
        sourceNode = nil
        eqNode     = nil
        reverbNode = nil
        isRunning  = false
    }

    // MARK: - Engine Construction

    private func buildAndStart(profile: SoundProfile) {
        let sampleRate: Double = 44_100
        guard let monoFmt = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else { return }

        let sr = Float(sampleRate)

        // ── Pink noise state (Paul Kellet's economy algorithm) ──
        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0

        // ── Brown noise state ──
        var brown: Float = 0

        // ── Modulation phases ──
        var ph1: Float = 0, ph2: Float = 0, ph3: Float = 0

        // ── Bell voices (parallel arrays — no heap alloc in render) ──
        let bellCount = profile.bells.count
        var bellPhase    = [Float](repeating: 0, count: max(1, bellCount))
        var bellAmp      = [Float](repeating: 0, count: max(1, bellCount))
        var bellDecay    = [Float](repeating: 0, count: max(1, bellCount))
        var bellCounter  = [Int](repeating: 0,   count: max(1, bellCount))
        var bellInterval = [Int](repeating: 0,   count: max(1, bellCount))

        // Pre-compute per-sample decay factors and initial retrigger intervals
        for i in 0..<bellCount {
            let b = profile.bells[i]
            bellDecay[i]    = expf(-1.0 / (b.decay * sr))
            bellInterval[i] = Int(b.interval * sr)
            bellCounter[i]  = Int(Float.random(in: 0.3...1.0) * b.interval * sr)
        }

        // ── Source node ──
        let src = AVAudioSourceNode(format: monoFmt) { _, _, frameCount, audioBufferList in
            guard let buf = UnsafeMutableAudioBufferListPointer(audioBufferList)
                    .first?.mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            for frame in 0..<Int(frameCount) {

                // 1. White noise seed
                let white = Float.random(in: -1.0...1.0)

                // 2. Pink noise (psychoacoustically flat — sounds most "natural")
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
                b6 = white * 0.115926

                // 3. Brown noise (deep rumble)
                brown = (brown + 0.02 * white) / 1.02

                // 4. Blend noise types
                let noise = pink    * profile.pinkWeight
                          + (brown * 6) * profile.brownWeight
                          + white  * (1 - profile.pinkWeight - profile.brownWeight)

                // 5. Multi-layer amplitude modulation
                var env: Float = 1.0
                if profile.mod1.freq > 0 {
                    let w = 0.5 + 0.5 * sinf(.pi * 2 * ph1)
                    env -= profile.mod1.depth * (1 - w)
                    ph1 += profile.mod1.freq / sr
                    if ph1 >= 1 { ph1 -= 1 }
                }
                if profile.mod2.freq > 0 {
                    let w = 0.5 + 0.5 * sinf(.pi * 2 * ph2)
                    env -= profile.mod2.depth * (1 - w)
                    ph2 += profile.mod2.freq / sr
                    if ph2 >= 1 { ph2 -= 1 }
                }
                if profile.mod3.freq > 0 {
                    let w = 0.5 + 0.5 * sinf(.pi * 2 * ph3)
                    env -= profile.mod3.depth * (1 - w)
                    ph3 += profile.mod3.freq / sr
                    if ph3 >= 1 { ph3 -= 1 }
                }
                env = max(0.05, env)   // never fully silent

                // 6. Bell voices with exponential decay + random retrigger
                var bellSum: Float = 0
                for i in 0..<bellCount {
                    bellCounter[i] -= 1
                    if bellCounter[i] <= 0 {
                        // Ring! Trigger with random amplitude
                        bellAmp[i]     = Float.random(in: 0.25...0.55)
                        // Next retrigger: base interval ± 40% jitter
                        let jitter = Float.random(in: 0.60...1.40)
                        bellCounter[i] = Int(jitter * Float(bellInterval[i]))
                    }
                    bellSum       += bellAmp[i] * sinf(.pi * 2 * bellPhase[i])
                    bellAmp[i]    *= bellDecay[i]                        // exponential fade
                    bellPhase[i]  += profile.bells[i].freq / sr
                    if bellPhase[i] >= 1 { bellPhase[i] -= 1 }
                }

                // 7. Mix and output
                let noisePart = noise * 0.70 * env * profile.gain
                let bellPart  = bellSum * 0.45 * profile.gain
                buf[frame] = noisePart + bellPart
            }
            return noErr
        }
        sourceNode = src

        // ── EQ: high-pass + low-pass for spectral shaping ──
        let eq = AVAudioUnitEQ(numberOfBands: 2)
        eq.bands[0].filterType = .highPass
        eq.bands[0].frequency  = profile.highpassCutoff
        eq.bands[0].bandwidth  = 1.0
        eq.bands[0].bypass     = false
        eq.bands[1].filterType = .lowPass
        eq.bands[1].frequency  = min(profile.lowpassCutoff, Float(sampleRate / 2) - 100)
        eq.bands[1].bandwidth  = 1.0
        eq.bands[1].bypass     = false
        eqNode = eq

        // ── Reverb: the single biggest quality leap ──────────────────────────
        // Raw noise synthesis sounds like speaker static.
        // Adding a room/space impulse response makes it sound like you're there.
        // Each sound profile picks the most natural-sounding preset for its type.
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(profile.reverbPreset)
        reverb.wetDryMix = profile.reverbMix   // 0 = dry only, 100 = fully wet
        reverbNode = reverb

        mixer.outputVolume = volume

        engine.attach(src)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(mixer)

        // Signal chain: src → EQ → Reverb → Mixer → Main output
        engine.connect(src,   to: eq,                   format: monoFmt)
        engine.connect(eq,    to: reverb,               format: monoFmt)
        engine.connect(reverb, to: mixer,               format: monoFmt)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        // Audio session was already configured in init() — just start the engine
        do {
            try engine.start()
            isRunning = true
        } catch {
            #if DEBUG
            print("[SoundEngine] Failed to start engine: \(error)")
            #endif
            // Re-try after re-activating the session (handles interruptions)
            try? AVAudioSession.sharedInstance().setActive(true)
            try? engine.start()
            isRunning = true
        }
    }
}
