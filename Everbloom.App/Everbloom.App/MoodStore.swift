// MoodStore.swift
// Everbloom — Daily mood check-in store
//
// Mirrors the JournalStore pattern:
//  • In-memory @Published array for instant UI reactivity
//  • UserDefaults for offline-first persistence
//  • Firestore sync on sign-in
//
// One entry per day maximum — save() replaces today's entry if it already exists.

import Foundation
import Combine

// Swift 6 fix: no @MainActor on the class (breaks @Published synthesis).
// Individual methods are marked @MainActor instead.
class MoodStore: ObservableObject {

    @Published var entries: [MoodEntry] = []    // newest first
    @Published var isSyncing = false

    private let localKey = "mood_checkins_v1"
    private let firestore = FirestoreManager.shared

    @MainActor
    init() { loadLocal() }

    // MARK: - Computed helpers

    /// Today's check-in, if the user has already logged one.
    @MainActor
    var todaysEntry: MoodEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    /// Whether the user has already checked in today.
    @MainActor
    var hasCheckedInToday: Bool { todaysEntry != nil }

    /// Entries whose date falls within the last `days` days, newest first.
    @MainActor
    func recentEntries(days: Int) -> [MoodEntry] {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -days, to: Date()
        ) else { return entries }
        return entries.filter { $0.date >= cutoff }
    }

    // MARK: - Public API

    /// Save (or replace today's) mood entry locally and sync to Firestore.
    @MainActor
    func save(_ entry: MoodEntry) {
        if let idx = entries.firstIndex(where: {
            Calendar.current.isDateInToday($0.date)
        }) {
            // Replace today's entry — user re-logged their mood
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        persistLocal()
        Task { try? await firestore.saveMoodEntry(entry) }
    }

    /// Pull all mood entries from Firestore after sign-in.
    @MainActor
    func syncFromCloud() {
        isSyncing = true
        Task { @MainActor in
            if let cloud = try? await firestore.loadMoodEntries(), !cloud.isEmpty {
                entries = cloud
                persistLocal()
            }
            isSyncing = false
        }
    }

    // MARK: - Local persistence (UserDefaults)

    @MainActor
    private func persistLocal() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    @MainActor
    private func loadLocal() {
        guard
            let data    = UserDefaults.standard.data(forKey: localKey),
            let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
