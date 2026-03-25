// ConversationStore.swift
// Everbloom — persists Bloom chat sessions across app launches

import Foundation
import Combine

// MARK: - Saved Message (Codable subset of ChatMessage)

struct SavedMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let role: String       // "user" | "assistant"
    let content: String
    let timestamp: Date

    init(from message: ChatMessage) {
        self.id        = message.id
        self.role      = message.isUser ? "user" : "assistant"
        self.content   = message.content
        self.timestamp = message.timestamp
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            role:      role == "user" ? .user : .assistant,
            content:   content,
            id:        id,
            timestamp: timestamp
        )
    }
}

// MARK: - Chat Session

struct ChatSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var messages: [SavedMessage]

    /// First user message, falling back to date string
    static func makeTitle(from messages: [ChatMessage]) -> String {
        messages.first(where: { $0.isUser })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(40)
            .description ?? "Conversation"
    }
}

// MARK: - Store

// Swift 6 fix: @MainActor on the class breaks @Published synthesis.
// Solution: no @MainActor on the class; mark individual methods @MainActor instead.
class ConversationStore: ObservableObject {
    @Published var sessions: [ChatSession] = []

    private let key = "bloom_conversations"

    @MainActor
    init() { load() }

    // MARK: Save / Update

    /// Saves or updates a chat session and returns the UUID of the session.
    /// ChatView uses the returned UUID to track the session across multiple saves,
    /// preventing duplicate entries when the user sends multiple messages.
    @MainActor
    @discardableResult
    func saveSession(id: UUID? = nil, messages: [ChatMessage]) -> UUID {
        let saved = messages.filter { $0.role != .system }.map { SavedMessage(from: $0) }

        // Nothing to save if the user hasn't typed anything yet
        guard saved.contains(where: { $0.role == "user" }) else {
            return id ?? UUID()
        }

        // Update existing session
        if let id, let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].messages = saved
            sessions[idx].date     = Date()
            sessions[idx].title    = ChatSession.makeTitle(from: messages)
            persist()
            return id
        }

        // Create a new session — return its ID so the caller can reuse it
        let session = ChatSession(
            title: ChatSession.makeTitle(from: messages),
            date: Date(),
            messages: saved
        )
        sessions.insert(session, at: 0)
        persist()
        return session.id
    }

    @MainActor
    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    // MARK: Persistence

    @MainActor
    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @MainActor
    private func load() {
        guard
            let data     = UserDefaults.standard.data(forKey: key),
            let decoded  = try? JSONDecoder().decode([ChatSession].self, from: data)
        else { return }
        sessions = decoded
    }
}
