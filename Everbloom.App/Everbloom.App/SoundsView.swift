// SoundsView.swift
// Everbloom — Anxiety & Panic Support App
// Calming sounds player with volume and fade-out timer

import SwiftUI

struct SoundsView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ZStack {
            ZenGradient.sounds.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // Header
                    VStack(spacing: 6) {
                        Text("Sounds")
                            .font(ZenFont.title(30))
                            .foregroundColor(.zenText)
                        Text("Let nature carry your mind to stillness")
                            .font(ZenFont.body(15))
                            .foregroundColor(.zenSubtext)
                    }
                    .padding(.top, 60)

                    // Sound grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(SoundOption.all) { sound in
                            SoundCard(sound: sound)
                                .environmentObject(audioManager)
                        }
                    }

                    // Now playing + controls
                    if let current = audioManager.currentSound {
                        nowPlayingPanel(current)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Now Playing

    private func nowPlayingPanel(_ sound: SoundOption) -> some View {
        VStack(spacing: 20) {

            // ── Title row ──
            HStack {
                Image(systemName: sound.icon)
                    .font(.system(size: 18))
                    .foregroundColor(sound.accentColor)
                Text("Now Playing: \(sound.name)")
                    .font(ZenFont.heading(16))
                    .foregroundColor(.zenText)
                Spacer()
                Button {
                    audioManager.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.zenSubtext)
                }
            }

            // ── Volume row: animated bars + mute button + slider ──
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {

                    // Tap speaker to mute / unmute
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            audioManager.toggleMute()
                        }
                    } label: {
                        Image(systemName: audioManager.isMuted
                              ? "speaker.slash.fill"
                              : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(audioManager.isMuted ? .zenSubtext.opacity(0.4) : sound.accentColor)
                            .frame(width: 26)
                            .animation(.easeInOut(duration: 0.2), value: audioManager.isMuted)
                    }

                    // Live equalizer bars — pulse when playing & not muted
                    VolumeEQView(
                        color: sound.accentColor,
                        isActive: audioManager.isPlaying && !audioManager.isMuted
                    )

                    Spacer()

                    Text(audioManager.isMuted
                         ? "Muted"
                         : "\(Int(audioManager.volume * 100))%")
                        .font(ZenFont.caption(13))
                        .foregroundColor(audioManager.isMuted ? .zenSubtext.opacity(0.4) : .zenSubtext)
                        .animation(.easeInOut(duration: 0.2), value: audioManager.isMuted)
                }

                Slider(value: $audioManager.volume, in: 0...1)
                    .tint(audioManager.isMuted ? .zenSubtext.opacity(0.3) : sound.accentColor)
                    .opacity(audioManager.isMuted ? 0.45 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: audioManager.isMuted)
            }

            // ── Fade-out timer ──
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 13))
                        .foregroundColor(.zenSubtext)
                    Text("Fade out after")
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                    Spacer()
                    Text(audioManager.fadeOutMinutes == 0
                         ? "Off"
                         : "\(Int(audioManager.fadeOutMinutes)) min")
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                }

                HStack(spacing: 10) {
                    ForEach([0.0, 10.0, 20.0, 30.0, 60.0], id: \.self) { mins in
                        Button {
                            audioManager.fadeOutMinutes = mins
                        } label: {
                            Text(mins == 0 ? "Off" : "\(Int(mins))m")
                                .font(ZenFont.caption(12))
                                .foregroundColor(audioManager.fadeOutMinutes == mins ? .white : .zenText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    audioManager.fadeOutMinutes == mins
                                    ? sound.accentColor
                                    : Color.white.opacity(0.5)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding(20)
        .zenCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioManager.currentSound?.id)
    }
}

// MARK: - Volume EQ Indicator
// Animated equalizer bars that pulse in sync with the sound.
// When muted or stopped, bars collapse to flat lines.

struct VolumeEQView: View {
    let color:    Color
    let isActive: Bool

    // Each bar animates at a slightly different speed for a natural look
    private let speeds: [Double] = [0.38, 0.52, 0.44, 0.58, 0.40, 0.50, 0.36]
    private let peaks:  [CGFloat] = [0.55, 0.90, 0.70, 1.00, 0.65, 0.80, 0.50]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<7, id: \.self) { i in
                EQBar(
                    color:    color,
                    isActive: isActive,
                    peak:     peaks[i],
                    speed:    speeds[i],
                    delay:    Double(i) * 0.06
                )
            }
        }
        .frame(height: 20)
    }
}

private struct EQBar: View {
    let color:    Color
    let isActive: Bool
    let peak:     CGFloat
    let speed:    Double
    let delay:    Double

    @State private var height: CGFloat = 0.15

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 3, height: 20 * (isActive ? height : 0.15))
            .onAppear   { animateIfNeeded() }
            .onChange(of: isActive) { _, _ in animateIfNeeded() }
    }

    private func animateIfNeeded() {
        guard isActive else {
            withAnimation(.easeOut(duration: 0.35)) { height = 0.15 }
            return
        }
        withAnimation(
            .easeInOut(duration: speed)
            .repeatForever(autoreverses: true)
            .delay(delay)
        ) {
            height = peak
        }
    }
}

// MARK: - Sound Card

struct SoundCard: View {
    let sound: SoundOption
    @EnvironmentObject var audioManager: AudioManager
    @State private var isPressed = false

    private var isActive: Bool { audioManager.isCurrentlyPlaying(sound) }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            audioManager.play(sound)
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isActive ? sound.accentColor : sound.accentColor.opacity(0.25))
                        .frame(width: 56, height: 56)

                    Image(systemName: isActive ? "pause.fill" : sound.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? .white : sound.accentColor)
                }

                VStack(spacing: 3) {
                    Text(sound.name)
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenText)
                    Text(sound.description)
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                if isActive {
                    SoundWaveView(color: sound.accentColor, isPlaying: true, barCount: 4, height: 18)
                } else {
                    Spacer().frame(height: 18)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? sound.accentColor.opacity(0.12) : Color.white.opacity(0.65))
                    .shadow(color: isActive ? sound.accentColor.opacity(0.25) : .zenDusk.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(SoundCardButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Sound Wave Animation

struct SoundWaveView: View {
    let color: Color
    let isPlaying: Bool
    var barCount: Int = 5
    var height: CGFloat = 24

    @State private var phases: [CGFloat] = []

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: isPlaying ? height * amplitudes[i % amplitudes.count] : height * 0.25)
                    .animation(
                        isPlaying
                        ? .easeInOut(duration: 0.4 + Double(i) * 0.08)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.07)
                        : .easeOut(duration: 0.3),
                        value: isPlaying
                    )
            }
        }
        .frame(height: height)
    }

    // Random-ish wave heights
    private let amplitudes: [CGFloat] = [0.4, 0.75, 1.0, 0.85, 0.55, 0.9, 0.6]
}

// MARK: - Button Style

struct SoundCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    SoundsView()
        .environmentObject(AudioManager())
}
