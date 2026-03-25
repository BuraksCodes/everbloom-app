// AppIntents.swift
// Everbloom — Siri Shortcuts & App Intents
//
// Users can add these to Siri by saying:
//   "Hey Siri, start a breathing exercise"
//   "Hey Siri, start panic relief"
//   "Hey Siri, log my mood"
//
// They also appear in the Shortcuts app for automation.
//
// Each intent opens the app (openAppWhenRun = true) and posts a
// NotificationCenter message that ContentView listens for to navigate.

import AppIntents
import SwiftUI

// MARK: - Start Breathing Exercise

@available(iOS 16.0, *)
struct StartBreathingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Breathing Exercise"
    static let description = IntentDescription(
        "Opens Everbloom and navigates to the breathing exercises.",
        categoryName: "Wellness"
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .everbloomOpenBreathing, object: nil)
        return .result()
    }
}

// MARK: - Start Panic Relief

@available(iOS 16.0, *)
struct StartPanicReliefIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Panic Relief"
    static let description = IntentDescription(
        "Opens Everbloom's emergency grounding and breathing flow.",
        categoryName: "Wellness"
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .everbloomOpenPanic, object: nil)
        return .result()
    }
}

// MARK: - Log Mood Check-In

@available(iOS 16.0, *)
struct LogMoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log My Mood"
    static let description = IntentDescription(
        "Opens Everbloom's daily mood check-in.",
        categoryName: "Wellness"
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .everbloomOpenMoodCheckin, object: nil)
        return .result()
    }
}

// MARK: - App Shortcuts Provider
// Surfaces these intents to Siri without the user having to record a phrase.

@available(iOS 16.4, *)
struct EverbloomShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBreathingIntent(),
            phrases: [
                "Start a breathing exercise in \(.applicationName)",
                "Open breathing in \(.applicationName)",
                "Help me breathe in \(.applicationName)",
            ],
            shortTitle: "Start Breathing",
            systemImageName: "lungs.fill"
        )
        AppShortcut(
            intent: StartPanicReliefIntent(),
            phrases: [
                "Start panic relief in \(.applicationName)",
                "I'm having a panic attack in \(.applicationName)",
                "Help me calm down in \(.applicationName)",
            ],
            shortTitle: "Panic Relief",
            systemImageName: "heart.fill"
        )
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Log my mood in \(.applicationName)",
                "Check in with \(.applicationName)",
                "How am I feeling in \(.applicationName)",
            ],
            shortTitle: "Log Mood",
            systemImageName: "face.smiling"
        )
    }
}
