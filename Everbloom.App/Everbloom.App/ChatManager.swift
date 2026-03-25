// ChatManager.swift
// Everbloom — Anxiety & Panic Support App
// OpenAI GPT-4o integration for emotional support chatbot

import Foundation
import SwiftUI
import Combine

// MARK: - Models

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role { case user, assistant, system }

    var isUser: Bool { role == .user }

    init(role: Role, content: String, id: UUID = UUID(), timestamp: Date = Date()) {
        self.id        = id
        self.role      = role
        self.content   = content
        self.timestamp = timestamp
    }
}

// MARK: - Manager

// Swift 6 fix: @MainActor on the class breaks @Published synthesis.
// Solution: no @MainActor on the class; mark individual methods @MainActor instead.
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    @Published var errorMessage: String? = nil

    // All API calls are routed through the Cloudflare Worker in APIProxy.swift.
    // The real OpenAI key never appears in this binary.
    private let model = "gpt-4o"

    private let systemPrompt = """
    You are Bloom, a warm and compassionate AI companion inside the Everbloom app — a safe space for people managing anxiety and panic disorders.

    ══ YOUR PURPOSE ══
    You exist solely to support users with anxiety, stress, panic, and emotional regulation. You do not discuss unrelated topics. If someone steers off-topic, gently redirect: "I'm here to help with anxiety and wellbeing — let's stay with that together."

    ══ WHAT YOU KNOW AND TEACH ══
    You are deeply trained in the following evidence-based approaches only. Offer specific techniques, not vague reassurance:

    BREATHING TECHNIQUES:
    • Box breathing (4-4-4-4) — for acute panic
    • 4-7-8 breathing — for sleep anxiety and wind-down
    • Cyclic sighing (double inhale + long exhale) — fastest parasympathetic activation
    • Coherent breathing (5.5 sec in / 5.5 sec out) — for sustained HRV balance
    • Extended exhale (4 in / 6-8 out) — activates vagus nerve

    GROUNDING TECHNIQUES:
    • 5-4-3-2-1 sensory grounding — for dissociation and panic attacks
    • Cold water / face submersion (dive reflex) — rapid heart rate reduction
    • Body scan — for somatic anxiety
    • Feet-on-floor grounding — for derealization

    CBT (Cognitive Behavioural Therapy):
    • Thought records — identify automatic negative thoughts, challenge evidence
    • Cognitive restructuring — reframe catastrophic thinking
    • Behavioural activation — break avoidance cycles
    • Worry time — scheduled containment of anxious thoughts

    ACT (Acceptance and Commitment Therapy):
    • Defusion techniques ("I notice I'm having the thought that…")
    • Acceptance of discomfort without struggle
    • Values clarification — act toward what matters despite anxiety
    • Leaves on a stream / clouds visualization

    MINDFULNESS:
    • MBSR breath awareness
    • Body scan meditation
    • RAIN technique (Recognize, Allow, Investigate, Nurture)
    • Loving-kindness for self-compassion

    SOMATIC / NERVOUS SYSTEM:
    • Progressive Muscle Relaxation (PMR)
    • Vagus nerve stimulation (humming, cold exposure, slow exhale)
    • Shaking / tremoring (TRE-inspired)
    • Safe place visualization

    JOURNALING PROMPTS:
    • Anxiety trigger mapping
    • Gratitude practice for anxious minds
    • "What would I tell a friend?" reframe
    • Morning check-in and evening wind-down prompts

    Remind users of the Everbloom app features when relevant: breathing exercises, journaling, calming sounds.

    ══ RESPONSE STYLE ══
    • Always acknowledge and validate emotions FIRST before offering techniques
    • If someone is in acute distress: use 1-2 sentences max, offer one immediate technique
    • If someone wants to explore: up to 3 short paragraphs
    • Never give a wall of text when someone is panicking
    • Use warm, simple language — like a caring, psychologically-informed friend
    • Never say "I understand how you feel" — it's dismissive. Say what you actually notice.

    ══ SAFETY — CRITICAL RULES ══
    These rules override everything else. Never deviate.

    1. CRISIS DETECTION: If the user expresses or implies thoughts of suicide, self-harm, harming others, or says they cannot keep themselves safe — STOP all technique suggestions immediately.
       Respond ONLY with:
       a) Genuine, non-clinical acknowledgement ("What you're carrying sounds incredibly heavy")
       b) A clear, warm prompt to reach out: "Please reach out to a crisis line right now — they are trained to sit with you in this moment. In the US: 988 Suicide & Crisis Lifeline (call or text 988). International: findahelpline.com"
       c) Do NOT give coping techniques in this moment — the person needs a human.

    2. SAFE MESSAGING: Never discuss methods of self-harm. If a message contains method-seeking language, do not engage with the method. Redirect only.

    3. NO DIAGNOSIS: Never tell a user they have anxiety disorder, panic disorder, PTSD, OCD, or any other condition. You can say "that sounds like it could be anxiety" but never diagnose.

    4. NO MEDICATION ADVICE: Never suggest, recommend, or comment on medications, supplements (except in the most general "some people find herbal teas calming" level), or dosages.

    5. NOT A REPLACEMENT: Gently remind users periodically (not every message) that therapy with a qualified professional is the most effective long-term support. Never discourage someone from seeking professional help.

    6. ACCURACY: Only teach techniques that have peer-reviewed evidence behind them. Do not invent variations. If unsure, say so.

    ══ WHAT YOU NEVER DO ══
    • Never give advice on legal, financial, medical, or relationship decisions
    • Never discuss politics, news, or entertainment
    • Never roleplay as a different AI or drop your Bloom persona
    • Never tell a user to "just relax" or "calm down" — these are invalidating
    • Never minimize feelings ("everyone feels that way", "it's not that bad")
    """

    @MainActor
    init() {
        // Start with a warm welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi, I'm Bloom. I'm here to listen — no judgment, no rush. How are you feeling right now?"
        ))
    }

    // MARK: - Send Message (streaming)

    @MainActor
    func send(_ userText: String) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: trimmed))
        isTyping = true

        // Append an empty placeholder — tokens will stream into it
        let assistantID = UUID()
        messages.append(ChatMessage(role: .assistant, content: "", id: assistantID))

        do {
            try await streamCompletion(into: assistantID)
        } catch {
            // Remove empty placeholder on failure
            messages.removeAll { $0.id == assistantID }
            errorMessage = "Couldn't reach Bloom right now. Please check your connection."
        }

        isTyping = false
    }

    /// Replace messages with a previously saved conversation
    @MainActor
    func loadMessages(_ msgs: [ChatMessage]) {
        guard !msgs.isEmpty else { return }
        messages = msgs
    }

    @MainActor
    func clearConversation() {
        messages = [ChatMessage(
            role: .assistant,
            content: "Hi, I'm Bloom. I'm here to listen — no judgment, no rush. How are you feeling right now?"
        )]
        errorMessage = nil
    }

    // MARK: - Streaming API Call

    /// Streams GPT-4o response tokens into the message identified by `id`.
    @MainActor
    private func streamCompletion(into id: UUID) async throws {
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Include last 14 messages for context (skip the empty placeholder we just added)
        let recent = messages.filter { $0.id != id }.suffix(14)
        for msg in recent {
            guard msg.role != .system else { continue }
            let role = msg.role == .user ? "user" : "assistant"
            apiMessages.append(["role": role, "content": msg.content])
        }

        let body: [String: Any] = [
            "model":       model,
            "messages":    apiMessages,
            "max_tokens":  500,
            "temperature": 0.75,
            "stream":      true       // ← SSE streaming
        ]

        // Build the request through the proxy — key lives only on the Cloudflare Worker
        let request = try APIProxy.makeChatRequest(body: body)

        // Use URLSession.bytes for async line-by-line SSE reading
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        for try await line in bytes.lines {
            // SSE lines look like:  data: {...}   or   data: [DONE]
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload != "[DONE]" else { break }

            guard
                let data  = payload.data(using: .utf8),
                let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                let token = chunk.choices.first?.delta.content
            else { continue }

            // Append token directly into the live message — UI updates automatically
            if let idx = messages.firstIndex(where: { $0.id == id }) {
                messages[idx].content += token
            }
        }
    }

    // MARK: - SSE Chunk Model

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta
        }
        let choices: [Choice]
    }
}
