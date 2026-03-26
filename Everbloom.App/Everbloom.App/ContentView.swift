// ContentView.swift
// Everbloom — Main navigation shell
// Uses a custom ZStack switcher instead of TabView to avoid iOS "More" overflow

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var audioManager:        AudioManager
    @EnvironmentObject var moodStore:           MoodStore
    @EnvironmentObject var authManager:         AuthManager
    @EnvironmentObject var journalStore:        JournalStore
    @State private var selectedTab:     AppTab = .home
    @State private var showingPanic             = false
    @State private var previousTab:     AppTab  = .home
    @State private var showingMoodCheckIn       = false
    @State private var showingPanicJournalEntry = false
    @State private var panicJournalDraft        = ""
    /// True while ChatListView has navigated into a ChatView detail — hides the tab bar
    @State private var tabBarHidden             = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── All tab views live in the hierarchy at all times (preserves state) ──
            ZStack {
                HomeView(showingPanic: $showingPanic, selectedTab: $selectedTab)
                    .tabVisible(selectedTab == .home)

                BreathingView()
                    .tabVisible(selectedTab == .breathe)

                MeditationLibraryView()
                    .tabVisible(selectedTab == .meditate)

                JournalView()
                    .tabVisible(selectedTab == .journal)

                ChatListView(tabBarHidden: $tabBarHidden)
                    .tabVisible(selectedTab == .chat)

                ProfileView()
                    .tabVisible(selectedTab == .profile)
            }
            .ignoresSafeArea(edges: .bottom)

            // ── Custom animated tab bar ──
            // Hidden (and non-interactive) while inside a ChatView detail push
            CustomTabBar(selectedTab: $selectedTab)
                .opacity(tabBarHidden ? 0 : 1)
                .allowsHitTesting(!tabBarHidden)
                .animation(.easeInOut(duration: 0.22), value: tabBarHidden)
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showingPanic) {
            PanicButtonView(isPresented: $showingPanic)
                .environmentObject(subscriptionManager)
                .environmentObject(journalStore)
        }
        // Panic → Journal handoff: open NewEntryView pre-filled with session context
        .sheet(isPresented: $showingPanicJournalEntry, onDismiss: {
            journalStore.panicSessionDraft = nil
        }) {
            NewEntryView(isPresented: $showingPanicJournalEntry, initialText: panicJournalDraft)
                .environmentObject(journalStore)
        }
        .onChange(of: journalStore.panicSessionDraft) { _, draft in
            guard let draft, !draft.isEmpty else { return }
            panicJournalDraft = draft
            // Switch to the journal tab so context is clear, then open composer
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .journal
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showingPanicJournalEntry = true
            }
        }
        // Daily mood check-in — fires once per day, with a 1 second delay so the
        // home screen finishes loading before the sheet slides up.
        .sheet(isPresented: $showingMoodCheckIn) {
            MoodCheckInView()
                .environmentObject(moodStore)
                .environmentObject(authManager)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !moodStore.hasCheckedInToday {
                    showingMoodCheckIn = true
                }
            }
        }
        .onChange(of: selectedTab) { old, new in
            previousTab = old
        }
        // Deep-link: notification tap → open mood check-in sheet
        .onReceive(NotificationCenter.default.publisher(for: .everbloomOpenMoodCheckin)) { _ in
            showingMoodCheckIn = true
        }
        // Deep-link: notification tap → switch to breathing tab
        .onReceive(NotificationCenter.default.publisher(for: .everbloomOpenBreathing)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .breathe
            }
        }
        // Deep-link: Siri "panic relief" intent → open panic flow
        .onReceive(NotificationCenter.default.publisher(for: .everbloomOpenPanic)) { _ in
            showingPanic = true
        }
        // Deep-link: URL scheme from Quick Actions widget (everbloom://breathe etc.)
        .onOpenURL { url in
            guard url.scheme == "everbloom" else { return }
            switch url.host {
            case "breathe":
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedTab = .breathe
                }
            case "panic":
                showingPanic = true
            case "mood":
                showingMoodCheckIn = true
            default:
                break
            }
        }
    }
}

// MARK: - Tab Visibility Modifier

private extension View {
    /// Show/hide a tab while keeping it alive in the view hierarchy
    func tabVisible(_ isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .animation(.easeInOut(duration: 0.18), value: isVisible)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @State private var animatingTab: AppTab? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard tab != selectedTab else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    // Bounce animation on icon
                    animatingTab = tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        animatingTab = nil
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: selectedTab == tab ? 22 : 18, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(selectedTab == tab ? .zenPurple : .zenSubtext)
                            .scaleEffect(animatingTab == tab ? 1.3 : (selectedTab == tab ? 1.05 : 1.0))
                            .animation(
                                animatingTab == tab
                                    ? .spring(response: 0.25, dampingFraction: 0.5)
                                    : .spring(response: 0.3, dampingFraction: 0.7),
                                value: animatingTab
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)

                        Text(tab.rawValue)
                            .font(ZenFont.caption(10))
                            .foregroundColor(selectedTab == tab ? .zenPurple : .zenSubtext)
                            .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    // Active indicator dot
                    .overlay(alignment: .top) {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.zenPurple)
                                .frame(width: 20, height: 3)
                                .offset(y: -6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .zenDusk.opacity(0.10), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(JournalStore())
        .environmentObject(AudioManager())
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager())
        .environmentObject(MoodStore())
}
