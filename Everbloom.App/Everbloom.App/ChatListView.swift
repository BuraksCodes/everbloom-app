// ChatListView.swift
// Everbloom — conversation history with Bloom

import SwiftUI

struct ChatListView: View {
    /// Tells ContentView to hide the floating tab bar while inside a chat detail
    @Binding var tabBarHidden: Bool

    @StateObject private var store = ConversationStore()
    @State private var activePath: NavigationPath = NavigationPath()
    @State private var didAppear = false

    var body: some View {
        NavigationStack(path: $activePath) {
            ZStack {
                ZenGradient.background.ignoresSafeArea()

                // Ambient blobs
                Circle()
                    .fill(Color.zenLavender.opacity(0.18))
                    .frame(width: 260).blur(radius: 50)
                    .offset(x: -90, y: -200)
                Circle()
                    .fill(Color.zenPeach.opacity(0.14))
                    .frame(width: 220).blur(radius: 44)
                    .offset(x: 110, y: 260)

                VStack(spacing: 0) {
                    // Header
                    listHeader
                        .animatedEntry(delay: 0.05, appeared: didAppear)

                    if store.sessions.isEmpty {
                        emptyState
                            .animatedEntry(delay: 0.15, appeared: didAppear)
                    } else {
                        // ── List supports native swipe-to-delete; ScrollView does not ──
                        List {
                            ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, session in
                                NavigationLink(value: session) {
                                    SessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20)
                                )
                                .animatedEntry(
                                    delay: Double(index) * 0.06 + 0.1,
                                    appeared: didAppear
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation(.spring(response: 0.3)) {
                                            store.deleteSession(session)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .padding(.bottom, 100) // clearance for tab bar
                    }
                }
            }
            .navigationDestination(for: ChatSession.self) { session in
                ChatView(
                    store: store,
                    sessionID: session.id,
                    initialMessages: session.messages.map { $0.toChatMessage() }
                )
            }
            .navigationDestination(for: String.self) { _ in
                ChatView(store: store, sessionID: nil, initialMessages: [])
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                didAppear = true
            }
        }
        // Hide/show the tab bar as the nav stack deepens / unwinds
        .onChange(of: activePath) { _, newPath in
            withAnimation(.easeInOut(duration: 0.22)) {
                tabBarHidden = !newPath.isEmpty
            }
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Bloom")
                    .font(ZenFont.title(26))
                    .foregroundColor(.zenText)
                Text("Your calm companion")
                    .font(ZenFont.caption(13))
                    .foregroundColor(.zenSubtext)
            }

            Spacer()

            // New chat button
            Button {
                activePath.append("new")
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.zenPurple)
                    .padding(10)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(color: .zenDusk.opacity(0.08), radius: 5, x: 0, y: 2)
            }
            .padding(.trailing, 8)

            // Avatar
            Image("BloomAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .shadow(color: .zenLavender.opacity(0.35), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("BloomAvatar")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .shadow(color: .zenLavender.opacity(0.3), radius: 16, x: 0, y: 6)

            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(ZenFont.heading(20))
                    .foregroundColor(.zenText)
                Text("Bloom is here to listen.\nNo judgment, no rush.")
                    .font(ZenFont.body(15))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                activePath.append("new")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 15, weight: .medium))
                    Text("Talk to Bloom")
                        .font(ZenFont.heading(16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .zenPurple.opacity(0.35), radius: 10, x: 0, y: 4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: ChatSession

    private var preview: String {
        session.messages.last(where: { $0.role == "assistant" })?.content
            ?? session.messages.last?.content
            ?? "…"
    }

    private var formattedDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(session.date) {
            let f = DateFormatter(); f.dateFormat = "h:mm a"
            return f.string(from: session.date)
        } else if cal.isDateInYesterday(session.date) {
            return "Yesterday"
        } else {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return f.string(from: session.date)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image("BloomAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .shadow(color: .zenLavender.opacity(0.25), radius: 5, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(session.title)
                        .font(ZenFont.heading(15))
                        .foregroundColor(.zenText)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedDate)
                        .font(ZenFont.caption(12))
                        .foregroundColor(.zenSubtext.opacity(0.7))
                }

                Text(preview)
                    .font(ZenFont.body(13))
                    .foregroundColor(.zenSubtext)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.72))
        .cornerRadius(18)
        .shadow(color: .zenDusk.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    ChatListView(tabBarHidden: .constant(false))
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager())
}
