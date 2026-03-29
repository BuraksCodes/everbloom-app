// SubscriptionManager.swift
// Everbloom — Premium subscription management via RevenueCat + Apple IAP
//
// ── One-time setup checklist ──────────────────────────────────────────────────
// 1. App Store Connect → In-App Purchases → create two Auto-Renewable Subscriptions:
//      • com.everbloom.premium.monthly  ($7.99/mo)
//      • com.everbloom.premium.annual   ($49.99/yr)
// 2. RevenueCat dashboard → create an Entitlement called "premium"
//    and attach both products to it
// 3. Swap in your live API key below when ready to ship (starts with "appl_...")
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import SwiftUI
import Combine
import RevenueCat

// MARK: - Subscription Products

struct SubscriptionProduct: Identifiable {
    let id: String
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isPopular: Bool
}

// MARK: - Manager

// Swift 6 fix: @MainActor on the class breaks @Published + @AppStorage synthesis.
// Solution: no @MainActor on the class; mark individual methods @MainActor instead.
class SubscriptionManager: ObservableObject {

    // ── Public state ──
    @Published var isPremium: Bool = false
    @Published var showingPaywall: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil

    // ── Tester override — flip this ON in Profile → Tester Mode ──
    @AppStorage("testerPremiumOverride") var testerPremiumOverride: Bool = false {
        didSet { if testerPremiumOverride { isPremium = true } else { Task { await refreshPremiumStatus() } } }
    }

    /// True in Xcode/Simulator (DEBUG) and in TestFlight distribution.
    /// Always false for App Store production builds — Tester Mode is hidden there.
    var isInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        // Method 1: TestFlight/Ad-hoc builds contain an embedded provisioning profile.
        // Apple strips this file entirely when processing an App Store submission.
        let provisionPath = Bundle.main.bundlePath.appending("/embedded.mobileprovision")
        if FileManager.default.fileExists(atPath: provisionPath) {
            return true
        }
        // Method 2: TestFlight receipt URL path contains "sandboxReceipt";
        // App Store receipt URL path contains "receipt".
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return true
        }
        return false
        #endif
    }

    // ── Free-tier limits ──
    static let freeDailyBloomMessages = 10
    static let freeJournalEntryLimit  = 20
    static let freeBreathingCount     = 3
    static let freeSoundCount         = 2

    // ── Daily Bloom message tracker ──
    @AppStorage("bloomMsgDate")  private var bloomMsgDate:  String = ""
    @AppStorage("bloomMsgCount") private var bloomMsgCount: Int    = 0

    private let revenueCatAPIKey = "appl_eNCuGKDWTMGjKIcawIwtjBgzzHt"

    // MARK: Init

    @MainActor
    init() {
        #if DEBUG
        Purchases.logLevel = .warn
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: revenueCatAPIKey)

        // Apply tester override immediately on launch if previously enabled
        if testerPremiumOverride { isPremium = true }

        Task { await refreshPremiumStatus() }
    }

    // MARK: - Premium Status

    @MainActor
    func refreshPremiumStatus() async {
        // Tester override always wins — skip RevenueCat check
        if testerPremiumOverride { isPremium = true; return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            // NOTE: The entitlement identifier must exactly match your RevenueCat dashboard.
            // Go to RevenueCat → Entitlements and confirm the identifier, then update below.
            isPremium = customerInfo.entitlements["Everbloom Pro"]?.isActive == true
        } catch {
            print("[RevenueCat] customerInfo error: \(error)")
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ productID: String) async {
        isPurchasing = true
        errorMessage = nil

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == productID
            }) else {
                errorMessage = "Product not available — please try again shortly."
                isPurchasing = false
                return
            }
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isPremium = result.customerInfo.entitlements["Everbloom Pro"]?.isActive == true
                if isPremium { showingPaywall = false }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    // MARK: - Restore Purchases

    @MainActor
    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements["Everbloom Pro"]?.isActive == true
            if !isPremium {
                errorMessage = "No active subscription found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    // MARK: - Feature Gates

    @MainActor
    var canSendBloomMessage: Bool {
        if isPremium { return true }
        resetDailyCountIfNeeded()
        return bloomMsgCount < SubscriptionManager.freeDailyBloomMessages
    }

    @MainActor
    var remainingBloomMessages: Int {
        if isPremium { return Int.max }
        resetDailyCountIfNeeded()
        return max(0, SubscriptionManager.freeDailyBloomMessages - bloomMsgCount)
    }

    @MainActor
    func recordBloomMessage() {
        resetDailyCountIfNeeded()
        bloomMsgCount += 1
    }

    @MainActor
    private func resetDailyCountIfNeeded() {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        if bloomMsgDate != today {
            bloomMsgDate  = today
            bloomMsgCount = 0
        }
    }

    // MARK: - Products (static UI labels — real pricing comes from RevenueCat/StoreKit)

    var products: [SubscriptionProduct] {
        [
            SubscriptionProduct(
                id: "com.everbloom.premium.monthly",
                title: "Monthly",
                price: "$7.99",
                period: "per month",
                savings: nil,
                isPopular: false
            ),
            SubscriptionProduct(
                id: "com.everbloom.premium.annual",
                title: "Annual",
                price: "$49.99",
                period: "per year",
                savings: "Save 48%",
                isPopular: true
            ),
        ]
    }
}

// MARK: - Premium Badge View

struct PremiumBadge: View {
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            if !compact {
                Text("PREMIUM")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
        }
        .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.28))
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 3)
        .background(Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.18))
        .clipShape(Capsule())
    }
}
