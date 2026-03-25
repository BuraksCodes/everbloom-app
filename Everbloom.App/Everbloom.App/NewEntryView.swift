// NewEntryView.swift
// Everbloom — Anxiety & Panic Support App
// New journal entry composer with guided prompts

import SwiftUI

struct NewEntryView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var journalStore: JournalStore

    /// Pre-fill the body field — used when launching from a panic session.
    var initialText: String? = nil

    @State private var title = ""
    @State private var entryText = ""
    @State private var selectedMood: JournalEntry.Mood = .neutral
    @State private var usedPrompt: String? = nil
    @State private var isSaving = false
    @State private var suggestedPrompts: [String] = JournalPrompts.suggestions(for: .neutral).prefix(3).map { $0 }
    @FocusState private var isBodyFocused: Bool

    var canSave: Bool { !entryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                ZenGradient.journal.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Mood picker
                        moodPicker

                        // Title field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITLE  (optional)")
                                .font(ZenFont.caption(11))
                                .foregroundColor(.zenSubtext)
                                .tracking(2)

                            TextField("Give this entry a title…", text: $title)
                                .font(ZenFont.heading(18))
                                .foregroundColor(.zenText)
                                .padding(14)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(14)
                        }

                        // Prompt section
                        promptSection

                        // Body field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR THOUGHTS")
                                .font(ZenFont.caption(11))
                                .foregroundColor(.zenSubtext)
                                .tracking(2)

                            ZStack(alignment: .topLeading) {
                                if entryText.isEmpty {
                                    Text(usedPrompt != nil ? "Write your response here…" : "What's on your mind?")
                                        .font(ZenFont.body(16))
                                        .foregroundColor(.zenSubtext.opacity(0.6))
                                        .padding(18)
                                }
                                TextEditor(text: $entryText)
                                    .font(ZenFont.body(16))
                                    .foregroundColor(.zenText)
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                                    .focused($isBodyFocused)
                                    .padding(12)
                            }
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(14)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(ZenFont.body(16))
                    .foregroundColor(.zenSubtext)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveEntry()
                    } label: {
                        Text("Save")
                            .font(ZenFont.heading(16))
                            .foregroundColor(canSave ? .zenPurple : .zenSubtext)
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Pre-fill body text when launched from a panic session
                if let draft = initialText, entryText.isEmpty {
                    entryText = draft
                    title = "Anxiety moment"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isBodyFocused = true
                }
            }
        }
    }

    // MARK: - Mood Picker

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("HOW ARE YOU FEELING?")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.zenSubtext)
                    .tracking(2)
                Spacer()
                // Selected mood label
                Text(selectedMood.rawValue)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenPurple)
                    .fontWeight(.medium)
            }

            HStack(spacing: 8) {
                ForEach(JournalEntry.Mood.allCases, id: \.self) { mood in
                    let isSelected = selectedMood == mood
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                            selectedMood = mood
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // Refresh mood-aware prompts
                        suggestedPrompts = JournalPrompts.suggestions(for: mood).prefix(3).map { $0 }
                    } label: {
                        VStack(spacing: 6) {
                            // Mood illustration
                            Image(mood.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: isSelected ? 54 : 46, height: isSelected ? 54 : 46)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            isSelected ? mood.color : Color.clear,
                                            lineWidth: 2.5
                                        )
                                )
                                .shadow(
                                    color: isSelected ? mood.color.opacity(0.5) : .clear,
                                    radius: 8, x: 0, y: 4
                                )
                                .scaleEffect(isSelected ? 1.0 : 0.92)

                            // Mood label
                            Text(mood.rawValue)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                                .foregroundColor(isSelected ? .zenPurple : .zenSubtext)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? mood.color.opacity(0.25) : Color.white.opacity(0.35))
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.32, dampingFraction: 0.68), value: selectedMood)
                }
            }
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.zenPurple)
                    Text("PROMPTS FOR \(selectedMood.rawValue.uppercased())")
                        .font(ZenFont.caption(11))
                        .foregroundColor(.zenSubtext)
                        .tracking(1.4)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        suggestedPrompts = JournalPrompts.suggestions(for: selectedMood).prefix(3).map { $0 }
                        if usedPrompt != nil { usedPrompt = nil }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Refresh")
                            .font(ZenFont.caption(12))
                    }
                    .foregroundColor(.zenPurple.opacity(0.8))
                }
            }

            // Three mood-matched prompt chips
            VStack(spacing: 8) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            usedPrompt = (usedPrompt == prompt) ? nil : prompt
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 10) {
                            // Selection indicator
                            ZStack {
                                Circle()
                                    .stroke(usedPrompt == prompt ? Color.zenPurple : Color.zenSubtext.opacity(0.30), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                if usedPrompt == prompt {
                                    Circle()
                                        .fill(Color.zenPurple)
                                        .frame(width: 10, height: 10)
                                }
                            }

                            Text(prompt)
                                .font(ZenFont.body(14))
                                .foregroundColor(usedPrompt == prompt ? .zenText : .zenSubtext)
                                .italic(usedPrompt == prompt)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(usedPrompt == prompt
                                      ? Color.zenLavender.opacity(0.45)
                                      : Color.white.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    usedPrompt == prompt
                                        ? Color.zenPurple.opacity(0.40)
                                        : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: usedPrompt)
                }
            }

            // Active prompt callout
            if let prompt = usedPrompt {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12))
                        .foregroundColor(.zenPurple.opacity(0.7))
                    Text("Using this prompt as your guide")
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenPurple.opacity(0.8))
                    Spacer()
                    Button {
                        withAnimation { usedPrompt = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.zenSubtext.opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.zenLavender.opacity(0.25))
                .cornerRadius(10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(prompt)
            }
        }
    }

    // MARK: - Save

    private func saveEntry() {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let entry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: entryText.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: selectedMood,
            promptUsed: usedPrompt
        )
        journalStore.save(entry)
        isPresented = false
    }
}

#Preview {
    NewEntryView(isPresented: .constant(true))
        .environmentObject(JournalStore())
}
