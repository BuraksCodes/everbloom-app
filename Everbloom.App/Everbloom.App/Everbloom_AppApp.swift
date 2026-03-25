//
//  Everbloom_AppApp.swift
//  Everbloom.App
//
//  Created by Burak Cakmakoglu on 2026-03-16.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Migrate any old OpenAI voice names ("nova"/"onyx") to ElevenLabs voice IDs.
        // This runs once after updating from the OpenAI TTS version.
        migrateVoicePreference()
        // Begin downloading real ambient sounds in the background.
        // SoundDownloader skips files that are already cached.
        Task { @MainActor in SoundDownloader.shared.downloadAllIfNeeded() }
        // Request HealthKit permission for mindful sessions (non-blocking).
        Task { await HealthKitManager.shared.requestAuthorization() }
        return true
    }
}

@main
struct Everbloom_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var journalStore        = JournalStore()
    @StateObject private var audioManager        = AudioManager()
    @StateObject private var authManager         = AuthManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var moodStore           = MoodStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(journalStore)
                .environmentObject(audioManager)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
                .environmentObject(moodStore)
        }
    }
}

// MARK: - Voice preference migration

/// Converts any stored OpenAI voice name ("nova"/"onyx") to the correct
/// ElevenLabs voice ID. Safe to call on every launch — does nothing if the
/// stored value is already a valid ElevenLabs ID.
private func migrateVoicePreference() {
    let key = "panicVoiceGender"
    let stored = UserDefaults.standard.string(forKey: key) ?? ""
    let validIDs = [APIProxy.voiceFemale, APIProxy.voiceMale]
    if !validIDs.contains(stored) {
        // "onyx" was the old male voice; everything else defaults to female
        let replacement = (stored == "onyx") ? APIProxy.voiceMale : APIProxy.voiceFemale
        UserDefaults.standard.set(replacement, forKey: key)
    }
}

// MARK: - Deep-link notification names

extension Notification.Name {
    static let everbloomOpenMoodCheckin = Notification.Name("everbloom.openMoodCheckin")
    static let everbloomOpenBreathing   = Notification.Name("everbloom.openBreathing")
    static let everbloomOpenPanic       = Notification.Name("everbloom.openPanic")
}

// MARK: - Root View (auth gate)

struct RootView: View {
    @EnvironmentObject var authManager:         AuthManager
    @EnvironmentObject var journalStore:        JournalStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var moodStore:           MoodStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                // First launch — show 3-screen walkthrough
                OnboardingView()
                    .transition(.opacity)
            } else if authManager.isSignedIn {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                AuthView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hasCompletedOnboarding)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: authManager.isSignedIn)
        // ── Global paywall sheet — triggered from anywhere via subscriptionManager.showingPaywall ──
        .sheet(isPresented: $subscriptionManager.showingPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if signedIn {
                journalStore.syncFromCloud()
                moodStore.syncFromCloud()
                if let user = authManager.user {
                    Task {
                        try? await FirestoreManager.shared.upsertUserProfile(
                            uid: user.uid,
                            email: user.email ?? "",
                            displayName: authManager.displayName
                        )
                    }
                }
            }
        }
    }
}
