// FirestoreManager.swift
// Everbloom — Anxiety & Panic Support App
// Handles all Cloud Firestore read/write operations

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

@MainActor
class FirestoreManager {

    static let shared = FirestoreManager()
    private let db = Firestore.firestore()

    // MARK: - Journal Entries

    /// Save or overwrite a journal entry for the current user
    func saveJournalEntry(_ entry: JournalEntry) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var data: [String: Any] = [
            "id":    entry.id.uuidString,
            "date":  Timestamp(date: entry.date),
            "title": entry.title,
            "body":  entry.body,
            "mood":  entry.mood.rawValue
        ]
        if let prompt = entry.promptUsed { data["promptUsed"] = prompt }

        try await db
            .collection("users").document(uid)
            .collection("journal").document(entry.id.uuidString)
            .setData(data)
    }

    /// Load all journal entries for the current user, sorted newest first
    func loadJournalEntries() async throws -> [JournalEntry] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db
            .collection("users").document(uid)
            .collection("journal")
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> JournalEntry? in
            let data = doc.data()
            guard
                let idStr   = data["id"]    as? String,
                let id      = UUID(uuidString: idStr),
                let ts      = data["date"]  as? Timestamp,
                let title   = data["title"] as? String,
                let body    = data["body"]  as? String,
                let moodRaw = data["mood"]  as? String,
                let mood    = JournalEntry.Mood(rawValue: moodRaw)
            else { return nil }

            return JournalEntry(
                id: id,
                date: ts.dateValue(),
                title: title,
                body: body,
                mood: mood,
                promptUsed: data["promptUsed"] as? String
            )
        }
    }

    /// Delete a journal entry for the current user
    func deleteJournalEntry(_ entry: JournalEntry) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db
            .collection("users").document(uid)
            .collection("journal").document(entry.id.uuidString)
            .delete()
    }

    // MARK: - Mood Check-Ins

    /// Save or overwrite a mood check-in entry for the current user
    func saveMoodEntry(_ entry: MoodEntry) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var data: [String: Any] = [
            "id":   entry.id.uuidString,
            "date": Timestamp(date: entry.date),
            "mood": entry.mood.rawValue
        ]
        if let note = entry.note { data["note"] = note }

        try await db
            .collection("users").document(uid)
            .collection("moodCheckins").document(entry.id.uuidString)
            .setData(data)
    }

    /// Load all mood check-in entries for the current user, newest first (max 90)
    func loadMoodEntries() async throws -> [MoodEntry] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db
            .collection("users").document(uid)
            .collection("moodCheckins")
            .order(by: "date", descending: true)
            .limit(to: 90)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> MoodEntry? in
            let data = doc.data()
            guard
                let idStr   = data["id"]   as? String,
                let id      = UUID(uuidString: idStr),
                let ts      = data["date"] as? Timestamp,
                let moodRaw = data["mood"] as? String,
                let mood    = JournalEntry.Mood(rawValue: moodRaw)
            else { return nil }

            return MoodEntry(
                id:   id,
                date: ts.dateValue(),
                mood: mood,
                note: data["note"] as? String
            )
        }
    }

    // MARK: - User Profile

    /// Create or update the user's profile document (called on sign-in)
    func upsertUserProfile(uid: String, email: String, displayName: String) async throws {
        let data: [String: Any] = [
            "email":       email,
            "displayName": displayName,
            "updatedAt":   FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - Account Deletion

    /// Deletes all Firestore data owned by this user: journals, moods, and the user profile doc.
    func deleteAllUserData(uid: String) async throws {
        // Delete journal entries
        let journals = try await db.collection("users").document(uid)
            .collection("journalEntries").getDocuments()
        for doc in journals.documents { try await doc.reference.delete() }

        // Delete mood entries
        let moods = try await db.collection("users").document(uid)
            .collection("moodEntries").getDocuments()
        for doc in moods.documents { try await doc.reference.delete() }

        // Delete the user profile document itself
        try await db.collection("users").document(uid).delete()
    }
}
