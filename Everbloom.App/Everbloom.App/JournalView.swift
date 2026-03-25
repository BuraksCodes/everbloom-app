// JournalView.swift
// Everbloom — Anxiety & Panic Support App
// Journal list with search and entry creation

import SwiftUI
import LocalAuthentication

struct JournalView: View {
    @EnvironmentObject var journalStore: JournalStore
    @State private var searchText = ""
    @State private var showingNewEntry = false
    @State private var selectedEntry: JournalEntry? = nil

    // Biometric lock
    @AppStorage("journalBiometricLock") private var biometricLockEnabled = false
    @State private var isUnlocked = false
    @State private var authError: String? = nil

    private var filteredEntries: [JournalEntry] {
        if searchText.isEmpty { return journalStore.entries }
        return journalStore.entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.mood.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        // Show lock screen when biometric lock is enabled and user isn't authenticated
        if biometricLockEnabled && !isUnlocked {
            journalLockScreen
        } else {
            journalContent
        }
    }

    // MARK: - Lock Screen

    private var journalLockScreen: some View {
        ZStack {
            ZenGradient.journal.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.zenLavender.opacity(0.22))
                            .frame(width: 96, height: 96)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.zenPurple, .zenLavender],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Journal Locked")
                            .font(ZenFont.title(26))
                            .foregroundColor(.zenText)
                        Text("Your journal is protected.\nAuthenticate to continue.")
                            .font(ZenFont.body(15))
                            .foregroundColor(.zenSubtext)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }

                if let err = authError {
                    Text(err)
                        .font(ZenFont.caption(13))
                        .foregroundColor(.zenRose)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    authError = nil
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricType == "Face ID" ? "faceid" : "touchid")
                            .font(.system(size: 18))
                        Text("Unlock with \(biometricType)")
                            .font(ZenFont.heading(17))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [.zenPurple, .zenLavender],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: .zenPurple.opacity(0.30), radius: 14, x: 0, y: 6)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .onAppear { authenticate() }
    }

    // MARK: - Biometric helpers

    private var biometricType: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    private func authenticate() {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Device has no biometrics — just unlock transparently
            isUnlocked = true
            return
        }
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your Everbloom journal"
        ) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.easeInOut(duration: 0.3)) { isUnlocked = true }
                } else if let e = evalError as? LAError, e.code != .userCancel {
                    authError = "Authentication failed. Please try again."
                }
            }
        }
    }

    // MARK: - Main journal content

    private var journalContent: some View {
        ZStack {
            ZenGradient.journal.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                journalHeader

                // Stats card — always visible
                journalStatsCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                if journalStore.entries.isEmpty {
                    emptyState
                } else {
                    // Search
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // Entries
                    entriesList
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntryView(isPresented: $showingNewEntry)
                .environmentObject(journalStore)
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry)
                .environmentObject(journalStore)
        }
        // Re-lock when the journal tab goes off-screen
        .onDisappear {
            if biometricLockEnabled { isUnlocked = false }
        }
    }

    // MARK: - Header

    private var journalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Journal")
                    .font(ZenFont.title(30))
                    .foregroundColor(.zenText)
                Text("\(journalStore.entries.count) entr\(journalStore.entries.count == 1 ? "y" : "ies")")
                    .font(ZenFont.caption(14))
                    .foregroundColor(.zenSubtext)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingNewEntry = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(colors: [.zenPurple, .zenRose], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    // MARK: - Stats Card

    private var journalStatsCard: some View {
        HStack(spacing: 0) {
            journalStat(
                value: journalStore.currentStreak > 0 ? "\(journalStore.currentStreak)" : "—",
                label: "Day Streak",
                icon: "flame.fill",
                color: journalStore.currentStreak > 0 ? .zenPeach : .zenSubtext
            )
            Divider()
                .frame(height: 36)
                .opacity(0.25)
            journalStat(
                value: "\(journalStore.entries.count)",
                label: "Total Entries",
                icon: "book.fill",
                color: .zenPurple
            )
            Divider()
                .frame(height: 36)
                .opacity(0.25)
            journalStat(
                value: "\(journalStore.entriesThisWeek)",
                label: "This Week",
                icon: "calendar",
                color: .zenSage
            )
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .shadow(color: .zenDusk.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }

    private func journalStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.zenText)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.zenSubtext)
                .font(.system(size: 15))
            TextField("Search entries…", text: $searchText)
                .font(ZenFont.body(15))
                .foregroundColor(.zenText)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.zenSubtext)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.7))
        .cornerRadius(14)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredEntries) { entry in
                    JournalEntryCard(entry: entry)
                        .onTapGesture { selectedEntry = entry }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { journalStore.delete(entry) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.zenSubtext.opacity(0.6))

            VStack(spacing: 8) {
                Text("Your journal awaits")
                    .font(ZenFont.heading(20))
                    .foregroundColor(.zenText)
                Text("Writing about your feelings is one of the most powerful ways to process anxiety.")
                    .font(ZenFont.body(15))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)

            Button {
                showingNewEntry = true
            } label: {
                Text("Write Your First Entry")
                    .font(ZenFont.heading(17))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.zenPurple, .zenRose], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: .zenRose.opacity(0.4), radius: 10, x: 0, y: 5)
            }

            Spacer()
        }
    }
}

// MARK: - Journal Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date + mood
            HStack {
                Text(entry.date, style: .date)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                Spacer()
                HStack(spacing: 5) {
                    Image(entry.mood.imageName)
                        .resizable().scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(entry.mood.rawValue)
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenText.opacity(0.75))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(entry.mood.color.opacity(0.55))
                .cornerRadius(20)
            }

            // Title
            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(ZenFont.heading(17))
                    .foregroundColor(.zenText)
                    .lineLimit(1)
            }

            // Body preview
            Text(entry.body)
                .font(ZenFont.body(14))
                .foregroundColor(.zenSubtext)
                .lineLimit(3)
                .lineSpacing(3)

            // Prompt used indicator
            if let prompt = entry.promptUsed {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 11))
                        .foregroundColor(.zenPurple.opacity(0.7))
                    Text(prompt)
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenPurple.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .zenCard()
    }
}

// MARK: - Entry Detail View

struct EntryDetailView: View {
    let entry: JournalEntry
    @EnvironmentObject var journalStore: JournalStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                ZenGradient.journal.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Meta
                        HStack {
                            Text(entry.date, style: .date)
                                .font(ZenFont.caption(14))
                                .foregroundColor(.zenSubtext)
                            Text("·")
                                .foregroundColor(.zenSubtext)
                            Text(entry.date, style: .time)
                                .font(ZenFont.caption(14))
                                .foregroundColor(.zenSubtext)
                            Spacer()
                            HStack(spacing: 5) {
                                Image(entry.mood.imageName)
                                    .resizable().scaledToFit()
                                    .frame(width: 15, height: 15)
                                Text(entry.mood.rawValue)
                                    .font(ZenFont.caption(13))
                                    .foregroundColor(.zenText.opacity(0.75))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(entry.mood.color.opacity(0.6))
                            .cornerRadius(20)
                        }

                        if !entry.title.isEmpty {
                            Text(entry.title)
                                .font(ZenFont.title(24))
                                .foregroundColor(.zenText)
                        }

                        if let prompt = entry.promptUsed {
                            Text("Prompt: \(prompt)")
                                .font(ZenFont.caption(13))
                                .foregroundColor(.zenPurple.opacity(0.75))
                                .italic()
                                .padding(12)
                                .background(Color.zenLavender.opacity(0.35))
                                .cornerRadius(12)
                        }

                        Text(entry.body)
                            .font(ZenFont.body(16))
                            .foregroundColor(.zenText)
                            .lineSpacing(6)

                        Spacer(minLength: 80)
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(ZenFont.body(16))
                        .foregroundColor(.zenPurple)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        journalStore.delete(entry)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
        }
    }
}

#Preview {
    JournalView()
        .environmentObject(JournalStore())
}
