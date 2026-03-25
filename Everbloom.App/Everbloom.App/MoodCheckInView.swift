// MoodCheckInView.swift
// Everbloom — Daily mood check-in sheet
//
// Shown once per day as a bottom sheet when the app opens.
// Also accessible by tapping "Log now" in HomeView's mood widget.
//
// Flow:
//  1. Greeting + "how are you feeling?" prompt
//  2. 5 emoji mood cards (spring animation on selection)
//  3. Optional one-line quick note
//  4. "Log My Mood" button → saves to MoodStore → dismisses
//  5. "Skip for today" link

import SwiftUI

struct MoodCheckInView: View {
    @EnvironmentObject var moodStore:   MoodStore
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected:   JournalEntry.Mood? = nil
    @State private var note:       String  = ""
    @State private var didAppear:  Bool    = false
    @State private var saved:      Bool    = false
    @FocusState private var noteFocused: Bool

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let first = authManager.displayName.components(separatedBy: " ").first
                  ?? authManager.displayName
        switch hour {
        case 5..<12:  return "Good morning, \(first)"
        case 12..<17: return "Good afternoon, \(first)"
        case 17..<22: return "Good evening, \(first)"
        default:      return "Hey, \(first)"
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

    // MARK: - Body

    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.93, blue: 0.99),
                    Color(red: 0.93, green: 0.96, blue: 0.99),
                    Color(red: 0.94, green: 0.99, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative blurred orbs
            Circle()
                .fill(Color.zenLavender.opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 55)
                .offset(x: -90, y: -200)
                .ignoresSafeArea()
            Circle()
                .fill(Color.zenSage.opacity(0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 45)
                .offset(x: 110, y: 220)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.zenSubtext.opacity(0.28))
                    .frame(width: 38, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Header ──────────────────────────────────────────
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text(greeting)
                                    .font(ZenFont.title(24))
                                    .foregroundColor(.zenText)
                                    .multilineTextAlignment(.center)
                                Image(systemName: greetingIcon)
                                    .font(.system(size: 20, weight: .medium))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(greetingIconColor)
                            }
                            .animatedEntry(delay: 0.05, appeared: didAppear)

                            Text("How are you feeling right now?")
                                .font(ZenFont.body(16))
                                .foregroundColor(.zenSubtext)
                                .multilineTextAlignment(.center)
                                .animatedEntry(delay: 0.12, appeared: didAppear)
                        }
                        .padding(.top, 16)

                        // ── Mood Cards ────────────────────────────────────
                        moodPicker
                            .animatedEntry(delay: 0.20, appeared: didAppear)

                        // ── Quick Note (appears after selection) ──────────
                        if selected != nil {
                            noteField
                                .transition(
                                    .move(edge: .bottom)
                                        .combined(with: .opacity)
                                )
                                .animatedEntry(delay: 0, appeared: didAppear)
                        }

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selected)
                }

                // ── Bottom CTA ────────────────────────────────────────────
                bottomActions
                    .animatedEntry(delay: 0.28, appeared: didAppear)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                didAppear = true
            }
        }
    }

    // MARK: - Mood Picker

    private var moodPicker: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(JournalEntry.Mood.allCases, id: \.self) { mood in
                    MoodPickerCard(
                        mood:       mood,
                        isSelected: selected == mood
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                            selected = mood
                        }
                    }
                }
            }

            // Selected label
            if let mood = selected {
                HStack(spacing: 6) {
                    Circle()
                        .fill(mood.color)
                        .frame(width: 8, height: 8)
                    Text("Feeling \(mood.rawValue.lowercased())")
                        .font(ZenFont.heading(15))
                        .foregroundColor(mood.color.opacity(0.90))
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .id(mood)
            }
        }
    }

    // MARK: - Quick Note Field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK NOTE  (optional)")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(1.2)

            TextField("What's on your mind?", text: $note, axis: .vertical)
                .font(ZenFont.body(15))
                .foregroundColor(.zenText)
                .focused($noteFocused)
                .lineLimit(1...3)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                        .shadow(color: .zenDusk.opacity(0.06), radius: 8, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            noteFocused ? Color.zenPurple.opacity(0.45) : Color.white.opacity(0.5),
                            lineWidth: 1.2
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: noteFocused)
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Primary CTA
            Button {
                guard let mood = selected else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let entry = MoodEntry(mood: mood, note: note.isEmpty ? nil : note)
                moodStore.save(entry)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    saved = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    dismiss()
                }
            } label: {
                ZStack {
                    if saved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(saved ? 1.0 : 0.5)
                    } else {
                        Text("Log My Mood")
                            .font(ZenFont.heading(16))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    Group {
                        if let mood = selected {
                            LinearGradient(
                                colors: [mood.color.opacity(0.90), Color.zenPurple.opacity(0.80)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.zenSubtext.opacity(0.25), Color.zenSubtext.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(
                    color: (selected?.color ?? .clear).opacity(saved ? 0 : 0.35),
                    radius: 12, x: 0, y: 5
                )
                .scaleEffect(saved ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: saved)
            }
            .disabled(selected == nil || saved)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)

            // Skip link
            Button("Skip for today") { dismiss() }
                .font(ZenFont.caption(14))
                .foregroundColor(.zenSubtext.opacity(0.75))
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
    }
}

// MARK: - Mood Picker Card

private struct MoodPickerCard: View {
    let mood:       JournalEntry.Mood
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(mood.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)

                Text(mood.rawValue)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? mood.color : .zenSubtext.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? mood.color.opacity(0.18) : Color.white.opacity(0.62))
                    .shadow(
                        color: isSelected ? mood.color.opacity(0.28) : Color.zenDusk.opacity(0.04),
                        radius: isSelected ? 9 : 4, x: 0, y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? mood.color.opacity(0.55) : Color.white.opacity(0.4),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
            )
            .scaleEffect(isSelected ? 1.07 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
