// ProfileView.swift
// Everbloom — Anxiety & Panic Support App

import SwiftUI
import FirebaseAuth
import PhotosUI
import LocalAuthentication

@MainActor
struct ProfileView: View {
    @EnvironmentObject var authManager:         AuthManager
    @EnvironmentObject var journalStore:        JournalStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingSignOutAlert      = false
    @State private var showTherapistFinder      = false
    @State private var showNotifDeniedAlert     = false
    @State private var showingDeleteAlert       = false
    @State private var isDeletingAccount        = false

    // Profile photo
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @AppStorage("profilePhotoData") private var profilePhotoData: Data = Data()

    // Voice preference — stores ElevenLabs voice ID (shared with meditation + panic button)
    @AppStorage("panicVoiceGender") private var voiceGender: String = APIProxy.voiceFemale

    // Privacy
    @AppStorage("journalBiometricLock") private var journalBiometricLock: Bool = false

    // Notification settings (mirrors OnboardingView keys)
    @AppStorage("moodReminderEnabled")    private var moodEnabled:     Bool = false
    @AppStorage("moodReminderHour")       private var moodHour:        Int  = 9
    @AppStorage("moodReminderMinute")     private var moodMinute:      Int  = 0
    @AppStorage("breathingReminderEnabled") private var breathEnabled: Bool = false
    @AppStorage("breathingReminderHour")  private var breathHour:      Int  = 14
    @AppStorage("breathingReminderMinute") private var breathMinute:   Int  = 0

    // Computed Date bindings for DatePicker
    private var moodReminderDate: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = moodHour; c.minute = moodMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c   = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                moodHour   = c.hour   ?? 9
                moodMinute = c.minute ?? 0
                if moodEnabled {
                    NotificationManager.shared.scheduleMoodReminder(hour: moodHour, minute: moodMinute)
                }
            }
        )
    }

    private var breathReminderDate: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents(); c.hour = breathHour; c.minute = breathMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c   = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                breathHour   = c.hour   ?? 14
                breathMinute = c.minute ?? 0
                if breathEnabled {
                    NotificationManager.shared.scheduleBreathingReminder(hour: breathHour, minute: breathMinute)
                }
            }
        )
    }

    @MainActor var profileImage: UIImage? {
        profilePhotoData.isEmpty ? nil : UIImage(data: profilePhotoData)
    }

    var body: some View {
        NavigationStack {
        ZStack {
            ZenGradient.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Avatar + name
                    profileHeader

                    // Stats
                    statsRow

                    // Premium subscription
                    premiumSection

                    // Therapist finder
                    therapistSection

                    // Reminders
                    remindersSection

                    // Audio & Voice
                    audioSection

                    // Privacy
                    privacySection

                    // Account section
                    accountSection

                    // Sign out
                    signOutButton

                    // Delete account
                    deleteAccountButton

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
        }
        .navigationBarHidden(true)
        } // NavigationStack
        .alert("Sign Out?", isPresented: $showingSignOutAlert) {
            Button("Sign Out", role: .destructive) { authManager.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your data.")
        }
        // ── Notifications denied ─────────────────────────────────────────────
        .alert("Notifications Disabled", isPresented: $showNotifDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everbloom needs notification permission to send reminders. You can enable it in Settings → Everbloom → Notifications.")
        }
        // ── Delete account confirmation ───────────────────────────────────────
        .alert("Delete Account?", isPresented: $showingDeleteAlert) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    await authManager.deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, journal entries, mood history, and all data. This cannot be undone.")
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { @MainActor in
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    profilePhotoData = data
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            // Photo picker wrapper
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    Group {
                        if let img = profileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [.zenLavender, .zenRose],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                Text(String(authManager.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            )
                        }
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .shadow(color: .zenLavender.opacity(0.45), radius: 14, x: 0, y: 4)

                    // Camera badge
                    ZStack {
                        Circle()
                            .fill(Color.zenPurple)
                            .frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .zenPurple.opacity(0.4), radius: 4, x: 0, y: 2)
                    .offset(x: 2, y: 2)
                }
            }

            VStack(spacing: 4) {
                Text(authManager.displayName)
                    .font(ZenFont.title(22))
                    .foregroundColor(.zenText)
                Text(authManager.userEmail)
                    .font(ZenFont.caption(14))
                    .foregroundColor(.zenSubtext)
            }

            // Tap hint
            Text("Tap photo to change")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext.opacity(0.6))
                .tracking(0.5)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Stats Row

    private var currentMood: JournalEntry.Mood? {
        journalStore.entries.sorted { $0.date > $1.date }.first?.mood
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(journalStore.entries.count)", label: "Journal\nEntries", color: .zenPeach)
            StatCard(value: streak(), label: "Day\nStreak", color: .zenSage)
            MoodStatCard(mood: currentMood)
        }
    }

    private func streak() -> String {
        guard !journalStore.entries.isEmpty else { return "0" }
        var count = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let sorted = journalStore.entries.sorted { $0.date > $1.date }
        for entry in sorted {
            let entryDay = Calendar.current.startOfDay(for: entry.date)
            if entryDay == checkDate {
                count += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return "\(count)"
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        VStack(spacing: 2) {
            Text("SUBSCRIPTION")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            if subscriptionManager.isPremium {
                // Already premium — show status + manage link
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.85, green: 0.72, blue: 0.28).opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.28))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium Active")
                                .font(ZenFont.heading(15))
                                .foregroundColor(.zenText)
                            Text("All features unlocked")
                                .font(ZenFont.caption(12))
                                .foregroundColor(.zenSubtext)
                        }
                        Spacer()
                        PremiumBadge()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 52).opacity(0.4)

                    // Manage / Cancel subscription
                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.zenSky.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.zenSky)
                            }
                            Text("Manage Subscription")
                                .font(ZenFont.body(15))
                                .foregroundColor(.zenText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.zenSubtext)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .zenCard()
            } else {
                // Upgrade prompt
                Button {
                    subscriptionManager.showingPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.zenPurple.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.zenPurple)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium")
                                .font(ZenFont.heading(15))
                                .foregroundColor(.zenText)
                            Text("Unlock all features from $7.99/mo")
                                .font(ZenFont.caption(12))
                                .foregroundColor(.zenSubtext)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.zenSubtext)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .zenCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Therapist Section

    private var therapistSection: some View {
        VStack(spacing: 2) {
            Text("SUPPORT")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            Button {
                if subscriptionManager.isPremium {
                    showTherapistFinder = true
                } else {
                    subscriptionManager.showingPaywall = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.zenSage.opacity(0.40))
                            .frame(width: 36, height: 36)
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 15))
                            .foregroundColor(.zenMoss)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find a Therapist")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                        Text("Browse nearby mental health professionals")
                            .font(ZenFont.caption(12))
                            .foregroundColor(.zenSubtext)
                    }
                    Spacer()
                    if !subscriptionManager.isPremium {
                        PremiumBadge(compact: true)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.zenSubtext)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .zenCard()
            }
            .buttonStyle(.plain)
        }
        .navigationDestination(isPresented: $showTherapistFinder) {
            TherapistFinderView()
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        VStack(spacing: 2) {
            Text("REMINDERS")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                // Mood check-in toggle row
                reminderRow(
                    icon:        "face.smiling.inverse",
                    title:       "Daily Mood Check-In",
                    color:       .zenPurple,
                    isOn:        $moodEnabled,
                    time:        moodReminderDate,
                    onToggle:    { on in
                        Task {
                            if on {
                                let granted = await NotificationManager.shared.requestPermission()
                                if granted {
                                    NotificationManager.shared.scheduleMoodReminder(
                                        hour: moodHour, minute: moodMinute)
                                } else {
                                    moodEnabled = false
                                    showNotifDeniedAlert = true
                                }
                            } else {
                                NotificationManager.shared.cancelMoodReminder()
                            }
                        }
                    }
                )

                Divider().padding(.leading, 52).opacity(0.4)

                // Breathing nudge toggle row
                reminderRow(
                    icon:        "wind",
                    title:       "Breathing Nudge",
                    color:       .zenSky,
                    isOn:        $breathEnabled,
                    time:        breathReminderDate,
                    onToggle:    { on in
                        Task {
                            if on {
                                let granted = await NotificationManager.shared.requestPermission()
                                if granted {
                                    NotificationManager.shared.scheduleBreathingReminder(
                                        hour: breathHour, minute: breathMinute)
                                } else {
                                    breathEnabled = false
                                    showNotifDeniedAlert = true
                                }
                            } else {
                                NotificationManager.shared.cancelBreathingReminder()
                            }
                        }
                    }
                )
            }
            .zenCard()
        }
    }

    @ViewBuilder
    private func reminderRow(
        icon:     String,
        title:    String,
        color:    Color,
        isOn:     Binding<Bool>,
        time:     Binding<Date>,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(ZenFont.body(15))
                    .foregroundColor(.zenText)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isOn.wrappedValue },
                    set: { newVal in
                        isOn.wrappedValue = newVal
                        onToggle(newVal)
                    }
                ))
                .labelsHidden()
                .tint(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Expanded time picker when enabled
            if isOn.wrappedValue {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.zenSubtext)
                        .padding(.leading, 16)
                    DatePicker(
                        "",
                        selection: time,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.80), value: isOn.wrappedValue)
    }

    // MARK: - Audio & Voice Section

    private var audioSection: some View {
        VStack(spacing: 2) {
            Text("AUDIO & VOICE")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                // Voice gender picker
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.zenLavender.opacity(0.40))
                            .frame(width: 36, height: 36)
                        Image(systemName: "waveform")
                            .font(.system(size: 15))
                            .foregroundColor(.zenPurple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Guide")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                        Text("Used in breathing, meditation & panic relief")
                            .font(ZenFont.caption(12))
                            .foregroundColor(.zenSubtext)
                    }
                    Spacer()
                    // Female / Male toggle
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                voiceGender = APIProxy.voiceFemale
                            }
                        } label: {
                            Text("Female")
                                .font(ZenFont.caption(12))
                                .foregroundColor(voiceGender == APIProxy.voiceFemale ? .white : .zenSubtext)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(voiceGender == APIProxy.voiceFemale ? Color.zenPurple : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                voiceGender = APIProxy.voiceMale
                            }
                        } label: {
                            Text("Male")
                                .font(ZenFont.caption(12))
                                .foregroundColor(voiceGender == APIProxy.voiceMale ? .white : .zenSubtext)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(voiceGender == APIProxy.voiceMale ? Color.zenPurple : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(3)
                    .background(Color.zenLavender.opacity(0.30))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                #if DEBUG
                Divider().padding(.leading, 52).opacity(0.4)

                // Tester premium override — DEBUG builds only, never shown in App Store
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tester Mode")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                        Text("Unlock all premium features for testing")
                            .font(ZenFont.caption(12))
                            .foregroundColor(.zenSubtext)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { subscriptionManager.testerPremiumOverride },
                        set: { subscriptionManager.testerPremiumOverride = $0 }
                    ))
                    .labelsHidden()
                    .tint(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                #endif
            }
            .zenCard()
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(spacing: 2) {
            Text("PRIVACY")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.zenSage.opacity(0.35))
                            .frame(width: 36, height: 36)
                        Image(systemName: biometricIconName)
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.20, green: 0.60, blue: 0.45))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Journal Lock")
                            .font(ZenFont.heading(15))
                            .foregroundColor(.zenText)
                        Text("Require \(biometricDisplayName) to open your journal")
                            .font(ZenFont.caption(12))
                            .foregroundColor(.zenSubtext)
                    }
                    Spacer()
                    Toggle("", isOn: $journalBiometricLock)
                        .labelsHidden()
                        .tint(.zenPurple)
                        .disabled(!deviceHasBiometrics)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .zenCard()

            if !deviceHasBiometrics {
                Text("Face ID / Touch ID is not available on this device.")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.zenSubtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
        }
    }

    private var deviceHasBiometrics: Bool {
        let ctx = LAContext()
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private var biometricIconName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }

    private var biometricDisplayName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 2) {
            Text("ACCOUNT")
                .font(ZenFont.caption(11))
                .foregroundColor(.zenSubtext)
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ProfileRow(icon: "envelope.fill", title: "Email", value: authManager.userEmail, color: .zenSky)
                Divider().padding(.leading, 52).opacity(0.4)
                ProfileRow(icon: "shield.fill", title: "Provider",
                           value: authManager.user?.providerData.first?.providerID == "apple.com" ? "Apple ID" : "Email",
                           color: .zenSage)
                Divider().padding(.leading, 52).opacity(0.4)
                ProfileRow(icon: "calendar", title: "Member since",
                           value: authManager.user?.metadata.creationDate.map {
                               DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
                           } ?? "—",
                           color: .zenPeach)
            }
            .zenCard()
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .font(ZenFont.heading(16))
            }
            .foregroundColor(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Delete Account

    private var deleteAccountButton: some View {
        Button {
            showingDeleteAlert = true
        } label: {
            HStack(spacing: 10) {
                if isDeletingAccount {
                    ProgressView()
                        .tint(.red.opacity(0.7))
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(isDeletingAccount ? "Deleting…" : "Delete Account & Data")
                    .font(ZenFont.heading(15))
            }
            .foregroundColor(.red.opacity(0.65))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.12), lineWidth: 1)
            )
        }
        .disabled(isDeletingAccount)
    }
}

// MARK: - Sub Views

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.zenText)
            Text(label)
                .font(ZenFont.caption(12))
                .foregroundColor(.zenSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.35))
        .cornerRadius(16)
    }
}

struct MoodStatCard: View {
    let mood: JournalEntry.Mood?

    var body: some View {
        VStack(spacing: 6) {
            if let mood {
                Image(mood.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                Text(mood.rawValue)
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 28))
                    .foregroundColor(.zenSubtext.opacity(0.4))
                Text("No mood\nyet")
                    .font(ZenFont.caption(12))
                    .foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.zenLavender.opacity(0.35))
        .cornerRadius(16)
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.2))
                .cornerRadius(8)

            Text(title)
                .font(ZenFont.body(15))
                .foregroundColor(.zenText)

            Spacer()

            Text(value)
                .font(ZenFont.caption(14))
                .foregroundColor(.zenSubtext)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(JournalStore())
        .environmentObject(SubscriptionManager())
}
