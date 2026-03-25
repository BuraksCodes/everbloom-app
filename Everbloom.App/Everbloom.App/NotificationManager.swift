// NotificationManager.swift
// Everbloom — Centralized push notification scheduling & handling
//
// Design:
//   • NotifCenterDelegate is the NSObject that satisfies UNUserNotificationCenterDelegate.
//     It is kept private so nothing else depends on it.
//   • NotificationManager is a plain @MainActor class — not ObservableObject.
//     All callers access it via NotificationManager.shared directly.

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Internal delegate (NSObject required by UNUserNotificationCenterDelegate)

private final class NotifCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Show notification banner even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    /// Route notification taps to the appropriate screen via NotificationCenter.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo["deepLink"] as? String ?? ""
        DispatchQueue.main.async {
            switch link {
            case NotificationManager.moodDeepLinkKey:
                NotificationCenter.default.post(name: .everbloomOpenMoodCheckin, object: nil)
            case NotificationManager.breatheDeepLinkKey:
                NotificationCenter.default.post(name: .everbloomOpenBreathing, object: nil)
            default:
                break
            }
        }
        handler()
    }
}

// MARK: - NotificationManager

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    // MARK: State

    private(set) var isAuthorized:        Bool                    = false
    private(set) var authorizationStatus: UNAuthorizationStatus  = .notDetermined

    // MARK: Notification identifiers

    private let moodID    = "com.everbloom.moodReminder"
    private let breatheID = "com.everbloom.breathingNudge"

    // MARK: Deep-link keys

    static let moodDeepLinkKey    = "everbloom.mood"
    static let breatheDeepLinkKey = "everbloom.breathe"

    // MARK: Delegate (keeps NSObject away from this class)

    private let delegate = NotifCenterDelegate()

    // MARK: Init

    private init() {
        UNUserNotificationCenter.current().delegate = delegate
        Task { await refreshStatus() }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshStatus() async {
        let settings        = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized        = settings.authorizationStatus == .authorized
    }

    // MARK: - Mood Check-In Reminder

    func scheduleMoodReminder(hour: Int, minute: Int) {
        schedule(
            id:       moodID,
            title:    "How are you feeling today? 🌸",
            body:     "Take a moment to check in with yourself.",
            hour:     hour,
            minute:   minute,
            deepLink: Self.moodDeepLinkKey
        )
    }

    func cancelMoodReminder() { cancel(id: moodID) }

    // MARK: - Breathing Nudge

    func scheduleBreathingReminder(hour: Int, minute: Int) {
        schedule(
            id:       breatheID,
            title:    "Time to breathe 🌬️",
            body:     "A 60-second session can shift your whole day.",
            hour:     hour,
            minute:   minute,
            deepLink: Self.breatheDeepLinkKey
        )
    }

    func cancelBreathingReminder() { cancel(id: breatheID) }

    // MARK: - Private helpers

    private func schedule(id: String, title: String, body: String,
                          hour: Int, minute: Int, deepLink: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        content.userInfo = ["deepLink": deepLink]

        var dc      = DateComponents()
        dc.hour     = hour
        dc.minute   = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancel(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
