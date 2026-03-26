// BreathingView.swift
// Everbloom — Anxiety & Panic Support App
// Guided breathing exercises — 10 scientifically-backed techniques (6 free · 4 Pro)

import SwiftUI

struct BreathingView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTechnique: BreathingTechnique = BreathingTechnique.box
    @State private var showingSession = false
    @State private var didAppear = false

    var body: some View {
        ZStack {
            // Background
            ZStack {
                LinearGradient(
                    colors: [
                        selectedTechnique.accentColor.opacity(0.22),
                        Color.bgTop,
                        Color.bgBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedTechnique.id)

                Circle()
                    .fill(selectedTechnique.accentColor.opacity(0.15))
                    .frame(width: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: -150)
                    .animation(.easeInOut(duration: 0.5), value: selectedTechnique.id)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 6) {
                        Text("Breathe")
                            .font(ZenFont.title(30))
                            .foregroundColor(.zenText)
                        Text("Science-backed techniques to calm your nervous system")
                            .font(ZenFont.body(14))
                            .foregroundColor(.zenSubtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)

                    // Scrollable technique cards
                    techniquePicker

                    // Detail card
                    techniqueDetailCard
                        .padding(.horizontal, 20)

                    // Begin button
                    let isCurrentLocked = selectedTechnique.isPro && !subscriptionManager.isPremium
                    Button {
                        if isCurrentLocked {
                            subscriptionManager.showingPaywall = true
                        } else {
                            showingSession = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isCurrentLocked ? "lock.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                            Text(isCurrentLocked ? "Unlock with Pro" : "Begin Session")
                                .font(ZenFont.heading(17))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: isCurrentLocked
                                    ? [Color(red: 0.55, green: 0.40, blue: 0.75), Color(red: 0.65, green: 0.50, blue: 0.85)]
                                    : [.zenPurple, selectedTechnique.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .zenPurple.opacity(0.30), radius: 14, x: 0, y: 6)
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.3), value: selectedTechnique.id)

                    Spacer(minLength: 100)
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { didAppear = true }
        }
        .fullScreenCover(isPresented: $showingSession) {
            BreathingSessionView(technique: selectedTechnique, isPresented: $showingSession)
        }
    }

    // MARK: - Horizontal Technique Picker

    private var techniquePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BreathingTechnique.all) { technique in
                    let isLocked = technique.isPro && !subscriptionManager.isPremium
                    Button {
                        if isLocked {
                            subscriptionManager.showingPaywall = true
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTechnique = technique
                            }
                        }
                    } label: {
                        TechniquePillCard(
                            technique: technique,
                            isSelected: selectedTechnique.id == technique.id,
                            isLocked: isLocked
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Detail Card

    private var techniqueDetailCard: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTechnique.name)
                        .font(ZenFont.title(21))
                        .foregroundColor(.zenText)
                    Text(selectedTechnique.subtitle)
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenSubtext)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(selectedTechnique.accentColor.opacity(0.35))
                        .frame(width: 50, height: 50)
                    Image(systemName: selectedTechnique.sfSymbol)
                        .font(.system(size: 20))
                        .foregroundColor(.zenPurple)
                }
            }

            // Recommended badge
            if let tag = selectedTechnique.recommendedTag {
                Text(tag)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.zenPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.zenLavender.opacity(0.5))
                    .clipShape(Capsule())
            }

            // Description
            Text(selectedTechnique.description)
                .font(ZenFont.body(14))
                .foregroundColor(.zenSubtext)
                .lineSpacing(4)

            Divider().opacity(0.35)

            // Phase breakdown
            VStack(spacing: 10) {
                ForEach(selectedTechnique.phases) { phase in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(selectedTechnique.accentColor)
                            .frame(width: 4, height: 38)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.label)
                                .font(ZenFont.caption(12))
                                .foregroundColor(.zenSubtext)
                            Text(phase.instruction)
                                .font(ZenFont.body(14))
                                .foregroundColor(.zenText)
                        }
                        Spacer()
                        Text("\(formatDuration(phase.duration))")
                            .font(.system(size: 20, weight: .light, design: .rounded))
                            .foregroundColor(.zenPurple)
                    }
                }
            }

            Divider().opacity(0.35)

            // Stats row
            HStack(spacing: 20) {
                statBadge(icon: "arrow.clockwise", value: "\(selectedTechnique.totalRounds) rounds")
                statBadge(icon: "clock", value: "~\(estimatedMinutes()) min")
                statBadge(icon: "waveform.path.ecg", value: "Proven")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .shadow(color: .zenDusk.opacity(0.08), radius: 14, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: selectedTechnique.id)
    }

    private func statBadge(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.zenSubtext)
            Text(value)
                .font(ZenFont.caption(12))
                .foregroundColor(.zenSubtext)
        }
    }

    private func formatDuration(_ d: Double) -> String {
        d == Double(Int(d)) ? "\(Int(d))s" : "\(d)s"
    }

    private func estimatedMinutes() -> Int {
        let total = selectedTechnique.phases.reduce(0) { $0 + $1.duration } * Double(selectedTechnique.totalRounds)
        return max(1, Int(ceil(total / 60)))
    }
}

// MARK: - Technique Pill Card

struct TechniquePillCard: View {
    let technique: BreathingTechnique
    let isSelected: Bool
    var isLocked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Technique icon with optional pro lock badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(technique.accentColor.opacity(isSelected ? 0.30 : 0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: technique.sfSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? technique.accentColor : .zenSubtext)
                        .opacity(isLocked ? 0.5 : 1)
                }
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color(red: 0.55, green: 0.40, blue: 0.75))
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }

            Text(technique.name
                .replacingOccurrences(of: " Breathing", with: "")
                .replacingOccurrences(of: "Diaphragmatic", with: "Belly")
            )
            .font(ZenFont.heading(14))
            .foregroundColor(isLocked ? .zenSubtext : (isSelected ? .zenPurple : .zenText))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            Text(technique.subtitle)
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 110)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isLocked ? Color.white.opacity(0.35) : (isSelected ? Color.white : Color.white.opacity(0.5)))
                .shadow(
                    color: isSelected ? Color.zenPurple.opacity(0.14) : .clear,
                    radius: 8, x: 0, y: 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isLocked ? Color(red: 0.55, green: 0.40, blue: 0.75).opacity(0.35)
                             : (isSelected ? Color.zenPurple.opacity(0.4) : Color.white.opacity(0.3)),
                    lineWidth: isSelected || isLocked ? 1.5 : 1
                )
        )
    }
}

// MARK: - Breathing Session

struct BreathingSessionView: View {
    let technique: BreathingTechnique
    @Binding var isPresented: Bool

    @State private var breathPhase  = 0
    @State private var breathScale: CGFloat = 0.72
    @State private var breathLabel  = "Get ready…"
    @State private var instruction  = "Find a comfortable position and close your eyes"
    @State private var phaseSeconds = 0
    @State private var currentRound = 1
    @State private var isComplete   = false
    @State private var sessionTimer: Timer? = nil
    @State private var hasStarted   = false
    @State private var arcProgress: CGFloat = 0.0   // sweeps 0→1 over each phase
    @State private var rippleScale: CGFloat = 1.0   // triggers on phase transition
    @State private var sessionStart: Date = Date()   // for HealthKit duration

    // MARK: Phase-aware colour

    private var phaseColor: Color {
        guard hasStarted, breathPhase < technique.phases.count else { return technique.accentColor }
        switch technique.phases[breathPhase].label {
        case "Inhale":        return technique.accentColor
        case "Hold", "Pause": return Color(red: 0.98, green: 0.80, blue: 0.38)  // warm gold
        case "Exhale":        return Color.zenSage
        case "Sniff more":    return technique.accentColor.opacity(0.80)
        default:              return technique.accentColor
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Gradient background shifts with phase colour
            LinearGradient(
                colors: [phaseColor.opacity(0.28), Color.bgTop, Color.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.7), value: breathPhase)

            if isComplete { completionView } else { sessionView }
        }
        .onAppear {
            sessionStart = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                hasStarted = true
                runPhase()
            }
        }
        .onDisappear { sessionTimer?.invalidate(); sessionTimer = nil }
    }

    // MARK: - Session View

    private var sessionView: some View {
        VStack(spacing: 0) {

            // ── Nav bar ──────────────────────────────────────────────────
            HStack {
                Button {
                    sessionTimer?.invalidate()
                    sessionTimer = nil
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.zenText.opacity(0.40))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(technique.name)
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenText)
                    Text("Round \(currentRound) of \(technique.totalRounds)")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext)
                }
                Spacer()
                // Round pip dots
                HStack(spacing: 5) {
                    ForEach(1...technique.totalRounds, id: \.self) { i in
                        Circle()
                            .fill(i <= currentRound ? phaseColor : Color.zenSubtext.opacity(0.22))
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.4), value: currentRound)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 12)

            Spacer()

            // ── Breathing circle ─────────────────────────────────────────
            ZStack {

                // Soft outer ripple rings (expand on phase start)
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(phaseColor.opacity(max(0, 0.10 - Double(i) * 0.03)), lineWidth: 1.2)
                        .frame(width: CGFloat(220 + i * 52))
                        .scaleEffect(breathScale * rippleScale)
                        .animation(
                            .easeInOut(duration: technique.phases[safe: breathPhase]?.duration ?? 4),
                            value: breathScale
                        )
                }

                // Countdown arc ring  ───────────────────────────────────
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 6)
                    .frame(width: 240, height: 240)

                // Sweeping fill arc
                Circle()
                    .trim(from: 0, to: arcProgress)
                    .stroke(
                        phaseColor.opacity(0.80),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0), value: arcProgress == 0) // snap reset
                    .animation(.easeInOut(duration: 0.3), value: breathPhase)

                // Main breathing orb  ───────────────────────────────────
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [phaseColor.opacity(0.70), phaseColor.opacity(0.18)],
                            center: .center,
                            startRadius: 18,
                            endRadius: 105
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(breathScale)
                    .shadow(color: phaseColor.opacity(0.40), radius: 32 * breathScale)
                    .animation(
                        .easeInOut(duration: technique.phases[safe: breathPhase]?.duration ?? 4),
                        value: breathScale
                    )
                    .animation(.easeInOut(duration: 0.6), value: breathPhase)

                // Label + countdown inside orb  ─────────────────────────
                VStack(spacing: 5) {
                    if hasStarted {
                        Image(systemName: BreathingTechnique.phaseIcon(
                            for: breathPhase < technique.phases.count
                                ? technique.phases[breathPhase].label : ""))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .transition(.scale.combined(with: .opacity))
                            .id("icon-\(breathPhase)")
                    }

                    Text(breathLabel)
                        .font(ZenFont.title(hasStarted ? 20 : 18))
                        .foregroundColor(.white)
                        .transition(.opacity.combined(with: .scale))
                        .id("label-\(breathLabel)")

                    if hasStarted && phaseSeconds > 0 {
                        Text("\(phaseSeconds)")
                            .font(.system(size: 42, weight: .ultraLight, design: .rounded))
                            .foregroundColor(.white.opacity(0.80))
                            .transition(.opacity)
                            .id("count-\(breathPhase)-\(phaseSeconds)")
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: breathLabel)
            }
            .frame(height: 320)

            Spacer(minLength: 12)

            // ── Instruction text ─────────────────────────────────────────
            Text(instruction)
                .font(ZenFont.body(15))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .frame(height: 48)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: instruction)

            Spacer(minLength: 20)

            // ── Phase segment bar ─────────────────────────────────────────
            // Shows each phase as a coloured segment; active one glows
            phaseSegmentBar
                .padding(.horizontal, 36)

            Spacer(minLength: 20)

            // ── Overall session progress bar ──────────────────────────────
            let totalPhases  = technique.phases.count * technique.totalRounds
            let donePhases   = (currentRound - 1) * technique.phases.count + breathPhase
            let totalProgress = totalPhases > 0 ? Double(donePhases) / Double(totalPhases) : 0

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 4)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.zenPurple, technique.accentColor],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * totalProgress, height: 4)
                        .animation(.easeInOut(duration: 0.5), value: totalProgress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 28)

            Spacer(minLength: 72)
        }
    }

    // MARK: Phase Segment Bar

    private var phaseSegmentBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<technique.phases.count, id: \.self) { i in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == breathPhase && hasStarted ? phaseColor : Color.white.opacity(0.28))
                        .frame(height: i == breathPhase && hasStarted ? 6 : 4)
                        .shadow(
                            color: i == breathPhase && hasStarted ? phaseColor.opacity(0.55) : .clear,
                            radius: 5
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: breathPhase)

                    Text(technique.phases[i].label)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(
                            i == breathPhase && hasStarted
                                ? phaseColor
                                : Color.white.opacity(0.40)
                        )
                        .lineLimit(1)
                        .animation(.easeInOut(duration: 0.3), value: breathPhase)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(technique.accentColor.opacity(0.18))
                    .frame(width: 120, height: 120)
                Image("BloomAvatar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .shadow(color: technique.accentColor.opacity(0.35), radius: 14, x: 0, y: 4)
            }
            VStack(spacing: 12) {
                Text("Session complete")
                    .font(ZenFont.title(28))
                    .foregroundColor(.zenText)
                Text("You completed all \(technique.totalRounds) rounds.\nYour nervous system thanks you.")
                    .font(ZenFont.body(16))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            Spacer()
            VStack(spacing: 14) {
                Button {
                    resetSession()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        hasStarted = true; runPhase()
                    }
                } label: {
                    Text("Breathe Again")
                        .font(ZenFont.heading(17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.zenPurple, technique.accentColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 28)

                Button { isPresented = false } label: {
                    Text("Return to Everbloom")
                        .font(ZenFont.body(16))
                        .foregroundColor(.zenSubtext)
                }
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: - Engine

    private func resetSession() {
        breathPhase = 0; breathScale = 0.72; arcProgress = 0
        breathLabel = "Get ready…"; instruction = "Find a comfortable position and close your eyes"
        currentRound = 1; isComplete = false; hasStarted = false; phaseSeconds = 0
    }

    private func haptic(for label: String) {
        switch label {
        case "Inhale":           UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "Hold", "Pause":    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case "Exhale":           UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "Sniff more":       UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        default:                 UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func runPhase() {
        guard breathPhase < technique.phases.count else {
            if currentRound < technique.totalRounds {
                currentRound += 1; breathPhase = 0; runPhase()
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                    isComplete = true
                }
                // Log completed session to Apple Health
                let end = Date()
                Task {
                    await HealthKitManager.shared.logMindfulSession(
                        start: sessionStart, end: end, source: "Breathing"
                    )
                }
            }
            return
        }

        let phase = technique.phases[breathPhase]
        breathLabel  = phase.label
        instruction  = phase.instruction
        phaseSeconds = Int(phase.duration)

        // Reset arc then animate sweep over phase duration
        arcProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: phase.duration)) {
                arcProgress = 1.0
            }
        }

        // Orb scale
        withAnimation(.easeInOut(duration: phase.duration)) {
            breathScale = phase.scale
        }

        // Ripple burst on transition
        withAnimation(.easeOut(duration: 0.25)) { rippleScale = 1.06 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.20)) { rippleScale = 1.0 }
        }

        haptic(for: phase.label)

        var elapsed = 0
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            elapsed += 1
            phaseSeconds = max(0, Int(phase.duration) - elapsed)
            if elapsed >= Int(phase.duration) {
                timer.invalidate()
                breathPhase += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { runPhase() }
            }
        }
    }
}

#Preview {
    BreathingView()
}
