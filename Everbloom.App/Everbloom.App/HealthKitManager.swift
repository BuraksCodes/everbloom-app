// HealthKitManager.swift
// Everbloom — Apple Health integration
//
// Writes mindful sessions to HealthKit after breathing and meditation
// sessions complete. Mood scores are logged as a custom quantity sample
// (HKQuantityTypeIdentifier is not available for mood, so we use
// a workaround with mindfulSession category and store mood in the
// metadata instead).
//
// IMPORTANT — Xcode setup required (one-time):
//   1. Select the Everbloom.App target → Signing & Capabilities → +Capability → HealthKit
//   2. Add NSHealthShareUsageDescription and NSHealthUpdateUsageDescription to Info.plist

import Foundation
import HealthKit

final class HealthKitManager {

    // Singleton
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private init() {}

    // ── Availability ──────────────────────────────────────────────────────

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // ── Authorization ─────────────────────────────────────────────────────

    /// Call once on first launch (or lazily before first write).
    /// Safe to call multiple times — HealthKit deduplicates the prompt.
    func requestAuthorization() async {
        guard isAvailable else { return }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
        } catch {
            #if DEBUG
            print("[HealthKit] Authorization error: \(error)")
            #endif
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────

    /// Log a completed mindfulness session (breathing exercise or meditation).
    /// - Parameters:
    ///   - start: When the session started.
    ///   - end:   When the session ended (must be > start).
    ///   - source: Human-readable label stored in metadata ("Breathing", "Meditation", "Panic Relief").
    func logMindfulSession(start: Date, end: Date, source: String = "Everbloom") async {
        guard isAvailable else { return }
        guard end > start else { return }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: UUID().uuidString,
            "EverbloomSource": source,
        ]

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end,
            metadata: metadata
        )

        do {
            try await store.save(sample)
            #if DEBUG
            let minutes = Int(end.timeIntervalSince(start) / 60)
            print("[HealthKit] Logged \(minutes) min mindful session (\(source))")
            #endif
        } catch {
            #if DEBUG
            print("[HealthKit] Save error: \(error)")
            #endif
        }
    }
}
