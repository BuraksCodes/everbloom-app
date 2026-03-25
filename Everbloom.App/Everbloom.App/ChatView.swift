// ChatView.swift
// Everbloom — Anxiety & Panic Support App
// AI companion chat powered by GPT-4o

import SwiftUI

// MARK: - Conversation starter prompts

private let chatStarterPrompts: [(emoji: String, text: String)] = [
    ("😰", "I'm feeling overwhelmed right now"),
    ("💭", "I can't stop having anxious thoughts"),
    ("😴", "Anxiety is keeping me awake at night"),
    ("💨", "Teach me a breathing technique"),
    ("📓", "Help me journal through my feelings"),
    ("🌊", "I just need to vent — can you listen?"),
    ("🧠", "Explain CBT to me simply"),
    ("💪", "How do I stop a panic attack?"),
]

// MARK: - Contextual suggestion chips

private let suggestionChipPools: [[String]] = [
    ["Tell me more", "Try a breathing exercise", "What else can I do?"],
    ["How does that help anxiety?", "Guide me through it", "I need something else"],
    ["That's really helpful", "Can you give an example?", "What's the next step?"],
    ["I want to try that", "Tell me more about CBT", "I'm still struggling"],
    ["Can we practice together?", "What if it doesn't work?", "Thank you, Bloom 🌸"],
]

struct ChatView: View {
    // When opened from ChatListView
    var store: ConversationStore? = nil
    var sessionID: UUID? = nil
    var initialMessages: [ChatMessage] = []

    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var chatManager = ChatManager()
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isInputFocused: Bool
    @State private var didAppear = false
    @State private var currentSessionID: UUID? = nil
    @State private var showLimitBanner = false
    @State private var suggestionPoolIndex = 0
    @Environment(\.dismiss) private var dismiss

    // True when only Bloom's opening welcome message exists
    private var isNewConversation: Bool {
        chatManager.messages.count == 1 && chatManager.messages.first?.role == .assistant
    }

    // The last assistant message (for suggestion chips)
    private var lastAssistantMessage: ChatMessage? {
        chatManager.messages.last(where: { $0.role == .assistant })
    }

    var body: some View {
        ZStack {
            // Background
            ZStack {
                ZenGradient.background.ignoresSafeArea()
                Circle()
                    .fill(Color.zenLavender.opacity(0.22))
                    .frame(width: 280).blur(radius: 55)
                    .offset(x: -80, y: -180)
                Circle()
                    .fill(Color.zenPeach.opacity(0.18))
                    .frame(width: 240).blur(radius: 50)
                    .offset(x: 120, y: 250)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                chatHeader

                // Messages
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(chatManager.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Typing indicator: only while streaming placeholder is still empty
                            if chatManager.isTyping && (chatManager.messages.last?.content ?? "").isEmpty {
                                TypingIndicator()
                                    .id("typing")
                            }

                            // Suggestion chips: shown after the last Bloom reply (not while typing)
                            if !chatManager.isTyping,
                               let last = lastAssistantMessage,
                               last.content.count > 4 {
                                SuggestionChips(
                                    chips: suggestionChipPools[suggestionPoolIndex % suggestionChipPools.count]
                                ) { chip in
                                    inputText = chip
                                    isInputFocused = true
                                }
                                .id("suggestions_\(last.id)")
                                .padding(.leading, 46) // align with Bloom bubble
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100) // extra room for starters + input
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: chatManager.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatManager.isTyping) { _, typing in
                        if typing { scrollToBottom(proxy: proxy) }
                        // Rotate suggestion pool on each Bloom reply
                        if !typing { suggestionPoolIndex += 1 }
                    }
                }

                // Conversation starters — shown only on fresh new chats
                if isNewConversation {
                    conversationStarters
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Error banner
                if let error = chatManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red.opacity(0.7))
                        Text(error)
                            .font(ZenFont.caption(13))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Free-tier limit banner
                if showLimitBanner {
                    Button {
                        subscriptionManager.showingPaywall = true
                        withAnimation { showLimitBanner = false }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.28))
                            Text("You've reached today's \(SubscriptionManager.freeDailyBloomMessages) free messages.")
                                .font(ZenFont.caption(13))
                                .foregroundColor(.zenText)
                            Spacer()
                            Text("Upgrade")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.zenPurple)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.12))
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Remaining message counter (free users only)
                if !subscriptionManager.isPremium && !showLimitBanner {
                    let remaining = subscriptionManager.remainingBloomMessages
                    if remaining <= 3 && remaining > 0 {
                        Text("\(remaining) free message\(remaining == 1 ? "" : "s") left today")
                            .font(ZenFont.caption(11))
                            .foregroundColor(.zenSubtext)
                            .padding(.vertical, 4)
                    }
                }

                // Input bar
                inputBar
            }
        }
        .opacity(didAppear ? 1 : 0)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Auto-save when leaving
                    if let store {
                        store.saveSession(id: currentSessionID, messages: chatManager.messages)
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Chats")
                            .font(ZenFont.body(16))
                    }
                    .foregroundColor(.zenPurple)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { didAppear = true }
            currentSessionID = sessionID
            // Load an existing conversation's messages
            if !initialMessages.isEmpty {
                chatManager.loadMessages(initialMessages)
            }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Bloom avatar
            Image("BloomAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .shadow(color: .zenLavender.opacity(0.4), radius: 6, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Bloom")
                    .font(ZenFont.heading(16))
                    .foregroundColor(.zenText)
                HStack(spacing: 5) {
                    Circle()
                        .fill(chatManager.isTyping ? Color.zenPeach : Color.zenSage)
                        .frame(width: 7, height: 7)
                        .scaleEffect(chatManager.isTyping ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                   value: chatManager.isTyping)
                    Text(chatManager.isTyping ? "typing…" : "Your calm companion")
                        .font(ZenFont.caption(12))
                        .foregroundColor(chatManager.isTyping ? .zenSubtext : .zenSubtext)
                        .animation(.easeInOut(duration: 0.2), value: chatManager.isTyping)
                }
            }

            Spacer()

            // Clear chat button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    chatManager.clearConversation()
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.zenSubtext)
                    .padding(8)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .zenDusk.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Share what's on your mind…", text: $inputText, axis: .vertical)
                .font(ZenFont.body(15))
                .foregroundColor(.zenText)
                .lineLimit(4)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.zenLavender.opacity(0.4), lineWidth: 1)
                )
                .onSubmit { sendMessage() }

            // Send button
            Button { sendMessage() } label: {
                ZStack {
                    Circle()
                        .fill(
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isTyping
                            ? AnyShapeStyle(Color.zenSubtext.opacity(0.2))
                            : AnyShapeStyle(LinearGradient(
                                colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        )
                        .frame(width: 42, height: 42)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .zenDusk.opacity(0.06), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Conversation Starters

    private var conversationStarters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S ON YOUR MIND?")
                .font(ZenFont.caption(10))
                .foregroundColor(.zenSubtext)
                .tracking(1.6)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(chatStarterPrompts, id: \.text) { item in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            inputText = item.text
                            isInputFocused = true
                        } label: {
                            HStack(spacing: 7) {
                                Text(item.emoji)
                                    .font(.system(size: 14))
                                Text(item.text)
                                    .font(ZenFont.caption(13))
                                    .foregroundColor(.zenText)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.78))
                            .cornerRadius(20)
                            .shadow(color: .zenDusk.opacity(0.06), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .zenDusk.opacity(0.04), radius: 4, x: 0, y: -2)
        )
    }

    // MARK: - Helpers

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatManager.isTyping else { return }

        // ── Free-tier message gate ──
        guard subscriptionManager.canSendBloomMessage else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showLimitBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showLimitBanner = false }
            }
            return
        }

        subscriptionManager.recordBloomMessage()
        inputText = ""
        isInputFocused = false
        Task {
            await chatManager.send(text)
            // Save after assistant replies.
            // Capture the returned UUID so every subsequent save in this
            // session updates the SAME entry — not a new one each time.
            if let store {
                let savedID = store.saveSession(id: currentSessionID, messages: chatManager.messages)
                if currentSessionID == nil {
                    currentSessionID = savedID
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if chatManager.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = chatManager.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 50) }

            if !message.isUser {
                // Bloom avatar
                Image("BloomAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .shadow(color: .zenLavender.opacity(0.3), radius: 4, x: 0, y: 1)
                    .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(ZenFont.body(15))
                    .foregroundColor(message.isUser ? .white : .zenText)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        Group {
                            if message.isUser {
                                LinearGradient(
                                    colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.92), Color.white.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .clipShape(
                        RoundedCornerShape(
                            radius: 18,
                            corners: message.isUser
                                ? [.topLeft, .topRight, .bottomLeft]
                                : [.topLeft, .topRight, .bottomRight]
                        )
                    )
                    .shadow(
                        color: message.isUser ? Color.zenPurple.opacity(0.20) : Color.zenDusk.opacity(0.07),
                        radius: 6, x: 0, y: 3
                    )

                Text(message.timestamp, style: .time)
                    .font(ZenFont.caption(10))
                    .foregroundColor(.zenSubtext.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 50) }
            if message.isUser {
                // User avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.zenPeach, .zenLavender],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                .alignmentGuide(.bottom) { d in d[.bottom] }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Suggestion Chips

struct SuggestionChips: View {
    let chips: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(chips, id: \.self) { chip in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onTap(chip)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.zenPurple.opacity(0.7))
                        Text(chip)
                            .font(ZenFont.caption(13))
                            .foregroundColor(.zenText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.78))
                            .shadow(color: .zenDusk.opacity(0.06), radius: 4, x: 0, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    /// Drives the wave: cycles 0 → 1 → 2 → 0 … via a repeating timer
    @State private var activeDot = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image("BloomAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.zenSubtext.opacity(activeDot == i ? 0.75 : 0.30))
                        .frame(width: 7, height: 7)
                        .offset(y: activeDot == i ? -4 : 0)
                        .animation(.easeInOut(duration: 0.35), value: activeDot)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.88))
            .clipShape(RoundedCornerShape(radius: 18, corners: [.topLeft, .topRight, .bottomRight]))
            .shadow(color: .zenDusk.opacity(0.07), radius: 6, x: 0, y: 3)

            Spacer(minLength: 50)
        }
        .onAppear { startWave() }
    }

    private func startWave() {
        func step(_ dot: Int) {
            activeDot = dot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                step((dot + 1) % 3)
            }
        }
        step(0)
    }
}

// MARK: - Rounded Corner Shape

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager())
}
