// TherapistFinderView.swift
// Everbloom — Find nearby therapists via Google Places API
// Premium feature — gated behind SubscriptionManager.isPremium
//
// Features:
//  • GPS location OR manual search (city, address, country)
//  • Distance radius filter (5 / 10 / 25 / 50 km)
//  • Gender preference filter (Any / Female / Male)
//  • Therapist / office photos via Google Places Photos API
//  • Coloured initials avatar fallback when no photo available
//  • Tap card → detail sheet: phone, website, open status, directions
//  • North America (US & Canada) focus with English results

import SwiftUI
import CoreLocation
import MapKit
import Observation

// MARK: - Models

struct TherapistResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let rating: Double?
    let userRatingsTotal: Int?
    let types: [String]
    let location: CLLocationCoordinate2D
    var distanceMeters: Double?
    var photoName: String?

    var formattedDistance: String {
        guard let d = distanceMeters else { return "" }
        if d < 1_000 { return "\(Int(d)) m away" }
        return String(format: "%.1f km away", d / 1_000)
    }

    var specialties: String {
        let map: [String: String] = [
            "psychologist":  "Psychologist",
            "psychiatrist":  "Psychiatrist",
            "counselor":     "Counsellor",
            "therapist":     "Therapist",
            "mental_health": "Mental Health",
            "doctor":        "Doctor",
            "health":        "Health",
        ]
        let readable = types.compactMap { map[$0] }
        return readable.isEmpty ? "Mental Health Professional" : readable.joined(separator: " · ")
    }

    /// First 1-2 capital letters of the practice name for the avatar fallback
    var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    /// Deterministic pastel gradient index based on name hash
    var avatarColorIndex: Int { abs(name.hashValue) % TherapistAvatarColors.count }
}

let TherapistAvatarColors: [(Color, Color)] = [
    (Color.zenPurple.opacity(0.7), Color.zenLavender),
    (Color(red: 0.30, green: 0.60, blue: 0.85), Color(red: 0.55, green: 0.80, blue: 0.95)),
    (Color(red: 0.25, green: 0.70, blue: 0.55), Color(red: 0.50, green: 0.85, blue: 0.72)),
    (Color(red: 0.75, green: 0.40, blue: 0.70), Color(red: 0.90, green: 0.65, blue: 0.85)),
    (Color(red: 0.85, green: 0.55, blue: 0.25), Color(red: 0.95, green: 0.75, blue: 0.50)),
]

struct TherapistDetail {
    var phoneNumber: String?
    var websiteURL:  String?
    var isOpenNow:   Bool?
}

enum GenderFilter: String, CaseIterable, Hashable {
    case any    = "Any"
    case female = "Female ♀"
    case male   = "Male ♂"

    var queryModifier: String {
        switch self {
        case .any:    return ""
        case .female: return "female "
        case .male:   return "male "
        }
    }
}

enum RadiusOption: Double, CaseIterable, Hashable {
    case five       = 5
    case ten        = 10
    case twentyFive = 25
    case fifty      = 50

    var label:  String { "\(Int(rawValue)) km" }
    var meters: Double { rawValue * 1_000 }
}

// MARK: - Location Delegate

final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onAuthChange: ((CLAuthorizationStatus) -> Void)?
    var onLocation:   ((CLLocation) -> Void)?
    var onError:      ((Error) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthChange?(manager.authorizationStatus)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.first else { return }
        onLocation?(loc)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }
}

// MARK: - ViewModel

@Observable
final class TherapistFinderViewModel {

    var therapists:      [TherapistResult]       = []
    var isLoading        = false
    var errorMessage:    String?                 = nil
    var locationDenied   = false
    var userLocation:    CLLocationCoordinate2D? = nil
    var currentLocationLabel: String             = "Current Location"

    // Filters
    var radiusOption:    RadiusOption = .ten
    var genderFilter:    GenderFilter = .any

    // Manual location search
    var locationQuery:   String  = ""
    var isGeocoding:     Bool    = false
    var useManualSearch: Bool    = false

    // Detail cache
    var detailCache:      [String: TherapistDetail] = [:]
    var isLoadingDetail   = false

    private let locationManager  = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private let geocoder         = CLGeocoder()

    @MainActor
    init() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.delegate = locationDelegate

        locationDelegate.onAuthChange = { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    self.locationDenied = false
                    self.locationManager.requestLocation()
                case .denied, .restricted:
                    self.locationDenied = true
                default: break
                }
            }
        }

        locationDelegate.onLocation = { [weak self] loc in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.userLocation = loc.coordinate
                // Reverse geocode to show "San Francisco, CA" in the UI
                if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc),
                   let p = placemarks.first {
                    let city    = p.locality ?? ""
                    let region  = p.administrativeArea ?? ""
                    let country = p.country ?? ""
                    let parts   = [city, region, country].filter { !$0.isEmpty }
                    self.currentLocationLabel = parts.prefix(2).joined(separator: ", ")
                }
                await self.searchTherapists(near: loc.coordinate)
            }
        }

        locationDelegate.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = "Location error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Location

    @MainActor
    func requestLocation() {
        useManualSearch = false
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default: break
        }
    }

    // MARK: - Manual Location Search (city, address, country)

    @MainActor
    func searchByAddress() async {
        let query = locationQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { requestLocation(); return }

        isGeocoding   = true
        errorMessage  = nil
        defer { isGeocoding = false }

        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            guard let first = placemarks.first, let loc = first.location else {
                errorMessage = "Could not find \"\(query)\". Try a city name or full address."
                return
            }
            useManualSearch = true
            userLocation    = loc.coordinate

            // Build a readable label for the search-near badge
            let city    = first.locality ?? first.name ?? ""
            let region  = first.administrativeArea ?? ""
            let country = first.country ?? ""
            let parts   = [city, region, country].filter { !$0.isEmpty }
            currentLocationLabel = parts.prefix(2).joined(separator: ", ")

            await searchTherapists(near: loc.coordinate)
        } catch {
            errorMessage = "Address not found: \(error.localizedDescription)"
        }
    }

    // MARK: - Google Places Text Search

    @MainActor
    func searchTherapists(near coord: CLLocationCoordinate2D) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        let urlString = "https://places.googleapis.com/v1/places:searchText"
        let query = "\(genderFilter.queryModifier)therapist psychologist psychiatrist counselor mental health"
        let placesBody: [String: Any] = [
            "textQuery":      query,
            "maxResultCount": 20,
            "languageCode":   "en",
            "locationBias": [
                "circle": [
                    "center": ["latitude": coord.latitude, "longitude": coord.longitude],
                    "radius": radiusOption.meters
                ]
            ]
        ]
        let fieldMask = "places.id,places.displayName,places.formattedAddress," +
                        "places.rating,places.userRatingCount,places.types," +
                        "places.location,places.photos"

        guard let req = try? APIProxy.makePlacesRequest(
            placesURL: urlString,
            fieldMask: fieldMask,
            body: placesBody
        ) else { errorMessage = "Request error."; return }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No response from server."; return
            }
            guard http.statusCode == 200 else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let err  = json["error"] as? [String: Any],
                   let msg  = err["message"] as? String {
                    errorMessage = msg
                } else {
                    errorMessage = "Server error (\(http.statusCode))."
                }
                return
            }
            guard let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let places = json["places"] as? [[String: Any]] else {
                errorMessage = "No therapists found nearby."; return
            }

            let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let results: [TherapistResult] = places.compactMap { place in
                guard
                    let id      = place["id"] as? String,
                    let display = place["displayName"] as? [String: Any],
                    let name    = display["text"] as? String,
                    let locDict = place["location"] as? [String: Any],
                    let lat     = locDict["latitude"]  as? Double,
                    let lng     = locDict["longitude"] as? Double
                else { return nil }

                let address     = place["formattedAddress"] as? String ?? "Address unavailable"
                let rating      = place["rating"] as? Double
                let ratingCount = place["userRatingCount"] as? Int
                let types       = place["types"] as? [String] ?? []
                let placeCoord  = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let dist        = userLoc.distance(from: CLLocation(latitude: lat, longitude: lng))
                let photos      = place["photos"] as? [[String: Any]]
                let photoName   = photos?.first?["name"] as? String

                return TherapistResult(
                    id: id, name: name, address: address,
                    rating: rating, userRatingsTotal: ratingCount,
                    types: types, location: placeCoord,
                    distanceMeters: dist, photoName: photoName
                )
            }
            .sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }

            therapists = results
            if therapists.isEmpty {
                errorMessage = "No therapists found within \(Int(radiusOption.rawValue)) km."
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    // MARK: - Place Details (lazy, cached)

    @MainActor
    func fetchDetails(for placeId: String) async -> TherapistDetail? {
        if let cached = detailCache[placeId] { return cached }
        isLoadingDetail = true; defer { isLoadingDetail = false }

        let urlString = "https://places.googleapis.com/v1/places/\(placeId)"
        guard let req = try? APIProxy.makePlacesGetRequest(
            placesURL: urlString,
            fieldMask: "nationalPhoneNumber,websiteUri,currentOpeningHours"
        ) else { return nil }

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let phone   = json["nationalPhoneNumber"] as? String
        let website = json["websiteUri"] as? String
        let openNow = (json["currentOpeningHours"] as? [String: Any])?["openNow"] as? Bool
        let detail  = TherapistDetail(phoneNumber: phone, websiteURL: website, isOpenNow: openNow)
        detailCache[placeId] = detail
        return detail
    }

    // MARK: - Maps

    @MainActor
    func openInMaps(_ therapist: TherapistResult) {
        let placemark = MKPlacemark(coordinate: therapist.location)
        let item      = MKMapItem(placemark: placemark)
        item.name     = therapist.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Place Photo View
// Tries header-based auth first (works with iOS-restricted API keys),
// then falls back to URL-param auth. Shows initials avatar on failure.

struct PlacePhotoView: View {
    let therapist: TherapistResult
    var size: CGFloat = 54
    @State private var uiImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                // Initials avatar — always looks polished even without a photo
                let colors = TherapistAvatarColors[therapist.avatarColorIndex]
                LinearGradient(
                    colors: [colors.0, colors.1],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Text(therapist.initials)
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .task(id: therapist.photoName ?? "") {
            guard let photoName = therapist.photoName, !photoName.isEmpty else { return }
            await loadPhoto(photoName: photoName)
        }
    }

    private func loadPhoto(photoName: String) async {
        // Route photo bytes through the Cloudflare Worker — API key stays server-side
        if let data = await APIProxy.fetchPlacesPhoto(photoName: photoName, maxWidthPx: 300),
           let img = UIImage(data: data) {
            await MainActor.run { self.uiImage = img }
        }
    }
}

// MARK: - Main View

struct TherapistFinderView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var vm       = TherapistFinderViewModel()
    @State private var appeared = false
    @State private var selected: TherapistResult? = nil

    var body: some View {
        ZStack {
            ZenGradient.background.ignoresSafeArea()
            Circle()
                .fill(Color.zenLavender.opacity(0.18))
                .frame(width: 280).blur(radius: 55)
                .offset(x: -100, y: -200)
            Circle()
                .fill(Color.zenSage.opacity(0.14))
                .frame(width: 240).blur(radius: 50)
                .offset(x: 120, y: 300)

            VStack(spacing: 0) {
                header
                titleRow

                if subscriptionManager.isPremium && !vm.locationDenied {
                    locationBar
                    if !vm.isLoading { filtersBar }
                }

                if !subscriptionManager.isPremium {
                    premiumGate
                } else if vm.locationDenied {
                    locationDeniedView
                } else if vm.isLoading || vm.isGeocoding {
                    loadingView
                } else if let err = vm.errorMessage, vm.therapists.isEmpty {
                    errorView(err)
                } else if vm.therapists.isEmpty {
                    emptyPrompt
                } else {
                    resultsList
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { appeared = true }
            if subscriptionManager.isPremium { vm.requestLocation() }
        }
        .sheet(item: $selected) { t in
            TherapistDetailSheet(therapist: t, vm: vm)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Profile").font(ZenFont.body(15))
                }
                .foregroundColor(.zenPurple)
            }
            Spacer()
            // Region badge — plain text, no emoji flags (they render as [?] on some devices)
            HStack(spacing: 5) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.zenPurple)
                Text("US & Canada")
                    .font(ZenFont.caption(11))
                    .foregroundColor(.zenSubtext)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.white.opacity(0.65))
            .clipShape(Capsule())
            .shadow(color: .zenDusk.opacity(0.06), radius: 4, x: 0, y: 1)

            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.zenPurple)
                .padding(10)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
                .shadow(color: .zenDusk.opacity(0.08), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal, 24).padding(.top, 64).padding(.bottom, 4)
        .animatedEntry(delay: 0.05, appeared: appeared)
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Find a Therapist")
                    .font(ZenFont.title(24)).foregroundColor(.zenText)
                if subscriptionManager.isPremium { PremiumBadge() }
            }
            Text("Licensed mental health professionals near you")
                .font(ZenFont.caption(13)).foregroundColor(.zenSubtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.bottom, 8)
        .animatedEntry(delay: 0.08, appeared: appeared)
    }

    // MARK: - Location Bar (search field + GPS button)

    private var locationBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.zenSubtext)

            TextField("City, address, or country…", text: $vm.locationQuery)
                .font(ZenFont.body(14))
                .foregroundColor(.zenText)
                .submitLabel(.search)
                .onSubmit {
                    Task { await vm.searchByAddress() }
                }

            if !vm.locationQuery.isEmpty {
                Button {
                    vm.locationQuery = ""
                    vm.requestLocation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.zenSubtext.opacity(0.6))
                }
            }

            // GPS button
            Button {
                vm.locationQuery = ""
                vm.requestLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(vm.useManualSearch ? .zenSubtext : .zenPurple)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .zenDusk.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 20).padding(.bottom, 6)
        .animatedEntry(delay: 0.09, appeared: appeared)
    }

    // MARK: - Filter Bar

    private var filtersBar: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Radius")
                        .font(ZenFont.caption(11)).foregroundColor(.zenSubtext)
                    ForEach(RadiusOption.allCases, id: \.self) { opt in
                        filterChip(label: opt.label, selected: vm.radiusOption == opt) {
                            vm.radiusOption = opt
                            triggerSearch()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 2)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Preference")
                        .font(ZenFont.caption(11)).foregroundColor(.zenSubtext)
                    ForEach(GenderFilter.allCases, id: \.self) { f in
                        filterChip(label: f.rawValue, selected: vm.genderFilter == f) {
                            vm.genderFilter = f
                            triggerSearch()
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 2)
            }
        }
        .padding(.bottom, 6)
        .animatedEntry(delay: 0.10, appeared: appeared)
    }

    private func triggerSearch() {
        if let loc = vm.userLocation {
            Task { await vm.searchTherapists(near: loc) }
        }
    }

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(ZenFont.caption(12))
                .foregroundColor(selected ? .white : .zenText)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    Group {
                        if selected {
                            LinearGradient(
                                colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.75)],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .clipShape(Capsule())
                .shadow(color: .zenDusk.opacity(selected ? 0.12 : 0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Premium Gate

    private var premiumGate: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 52)).foregroundColor(.zenPurple.opacity(0.6))
            VStack(spacing: 10) {
                Text("Premium Feature")
                    .font(ZenFont.heading(20)).foregroundColor(.zenText)
                Text("Upgrade to find licensed therapists near you —\nwith photos, contact info, and directions.")
                    .font(ZenFont.body(15)).foregroundColor(.zenSubtext)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
            Button { subscriptionManager.showingPaywall = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Unlock with Premium").font(ZenFont.heading(16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32).padding(.vertical, 16)
                .background(LinearGradient(colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule())
                .shadow(color: .zenPurple.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            Spacer()
        }
        .padding(.horizontal, 40).animatedEntry(delay: 0.1, appeared: appeared)
    }

    // MARK: - Location Denied

    private var locationDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48)).foregroundColor(.zenSubtext)
            Text("Location Access Required")
                .font(ZenFont.heading(18)).foregroundColor(.zenText)
            Text("Enable location in Settings, or type a city in the search bar above.")
                .font(ZenFont.body(15)).foregroundColor(.zenSubtext).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings").font(ZenFont.heading(15)).foregroundColor(.zenPurple)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.4).tint(.zenPurple)
            Text(vm.isGeocoding ? "Finding location…" : "Searching for therapists…")
                .font(ZenFont.body(15)).foregroundColor(.zenSubtext)
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 44)).foregroundColor(.zenSubtext)
            Text(message)
                .font(ZenFont.body(15)).foregroundColor(.zenSubtext).multilineTextAlignment(.center)
            Button {
                if let loc = vm.userLocation {
                    Task { await vm.searchTherapists(near: loc) }
                } else { vm.requestLocation() }
            } label: {
                Text("Try Again").font(ZenFont.heading(15)).foregroundColor(.zenPurple)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 48)).foregroundColor(.zenLavender)
            Text("Ready to search")
                .font(ZenFont.heading(18)).foregroundColor(.zenText)
            Text("Use your current location or search for\na city, address, or country.")
                .font(ZenFont.body(15)).foregroundColor(.zenSubtext).multilineTextAlignment(.center)
            Button { vm.requestLocation() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text("Use Current Location").font(ZenFont.heading(16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32).padding(.vertical, 16)
                .background(LinearGradient(colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule())
                .shadow(color: .zenPurple.opacity(0.30), radius: 8, x: 0, y: 3)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // "Searching near X" badge
                HStack(spacing: 6) {
                    Image(systemName: vm.useManualSearch ? "magnifyingglass" : "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.zenPurple)
                    Text("Near: \(vm.currentLocationLabel)")
                        .font(ZenFont.caption(12)).foregroundColor(.zenSubtext)
                    Spacer()
                    Text("\(vm.therapists.count) found")
                        .font(ZenFont.caption(12)).foregroundColor(.zenSubtext)
                    Button {
                        if let loc = vm.userLocation {
                            Task { await vm.searchTherapists(near: loc) }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.zenPurple)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 4)

                ForEach(Array(vm.therapists.enumerated()), id: \.element.id) { index, t in
                    TherapistCard(therapist: t) {
                        selected = t
                    } onDirections: {
                        vm.openInMaps(t)
                    }
                    .padding(.horizontal, 20)
                    .animatedEntry(delay: Double(index) * 0.05 + 0.05, appeared: appeared)
                }
            }
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Therapist Card

struct TherapistCard: View {
    let therapist:    TherapistResult
    let onTap:        () -> Void
    let onDirections: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Photo / initials avatar
                    PlacePhotoView(therapist: therapist, size: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(therapist.name)
                            .font(ZenFont.heading(15)).foregroundColor(.zenText)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        Text(therapist.specialties)
                            .font(ZenFont.caption(12)).foregroundColor(.zenPurple)
                    }

                    Spacer(minLength: 4)

                    VStack(alignment: .trailing, spacing: 4) {
                        if !therapist.formattedDistance.isEmpty {
                            Text(therapist.formattedDistance)
                                .font(ZenFont.caption(11)).foregroundColor(.zenSubtext)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.zenSubtext.opacity(0.45))
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12)).foregroundColor(.zenSubtext)
                    Text(therapist.address)
                        .font(ZenFont.caption(12)).foregroundColor(.zenSubtext)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }

                HStack {
                    if let rating = therapist.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                            Text(String(format: "%.1f", rating))
                                .font(ZenFont.caption(12)).foregroundColor(.zenText)
                            if let count = therapist.userRatingsTotal {
                                Text("(\(count))")
                                    .font(ZenFont.caption(11)).foregroundColor(.zenSubtext)
                            }
                        }
                    }
                    Spacer()
                    Button(action: onDirections) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.system(size: 13))
                            Text("Directions").font(ZenFont.caption(13))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.zenPurple).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.72))
            .cornerRadius(18)
            .shadow(color: .zenDusk.opacity(0.07), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Sheet

struct TherapistDetailSheet: View {
    let therapist: TherapistResult
    let vm: TherapistFinderViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var detail:    TherapistDetail? = nil
    @State private var isLoading: Bool             = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero photo / avatar
                    ZStack {
                        let colors = TherapistAvatarColors[therapist.avatarColorIndex]
                        LinearGradient(colors: [colors.0, colors.1],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(therapist.initials)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        // Overlay real photo if available
                        if therapist.photoName != nil {
                            PlacePhotoView(therapist: therapist, size: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .ignoresSafeArea(edges: .top)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(therapist.name)
                                .font(ZenFont.title(22)).foregroundColor(.zenText)
                            Text(therapist.specialties)
                                .font(ZenFont.caption(13)).foregroundColor(.zenPurple)
                        }

                        if let rating = therapist.rating {
                            HStack(spacing: 5) {
                                ForEach(0..<5) { i in
                                    let fill = Double(i) < rating
                                    let half = !fill && Double(i) < rating + 0.5
                                    Image(systemName: fill ? "star.fill" : half ? "star.leadinghalf.filled" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.25))
                                }
                                Text(String(format: "%.1f", rating))
                                    .font(ZenFont.caption(13)).foregroundColor(.zenText)
                                if let count = therapist.userRatingsTotal {
                                    Text("· \(count) reviews")
                                        .font(ZenFont.caption(12)).foregroundColor(.zenSubtext)
                                }
                            }
                        }

                        Divider()

                        if isLoading {
                            HStack { Spacer(); ProgressView().tint(.zenPurple); Spacer() }
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 10) {
                                if let openNow = detail?.isOpenNow {
                                    HStack(spacing: 8) {
                                        Circle().fill(openNow ? Color.green : Color.red)
                                            .frame(width: 8, height: 8)
                                        Text(openNow ? "Open now" : "Currently closed")
                                            .font(ZenFont.caption(13))
                                            .foregroundColor(openNow ? .green : .red)
                                        Spacer()
                                    }.padding(.bottom, 4)
                                }

                                detailRow(icon: "mappin.circle.fill", iconColor: .zenPurple,
                                          text: therapist.address, actionLabel: "Directions") {
                                    vm.openInMaps(therapist)
                                }
                                if !therapist.formattedDistance.isEmpty {
                                    detailInfoRow(icon: "location.fill", iconColor: .zenSage,
                                                  text: therapist.formattedDistance)
                                }
                                if let phone = detail?.phoneNumber {
                                    detailRow(icon: "phone.fill", iconColor: Color.green,
                                              text: phone, actionLabel: "Call") {
                                        let d = phone.filter { $0.isNumber || $0 == "+" }
                                        if let u = URL(string: "tel:\(d)") { UIApplication.shared.open(u) }
                                    }
                                }
                                if let web = detail?.websiteURL {
                                    let display = web
                                        .replacingOccurrences(of: "https://", with: "")
                                        .replacingOccurrences(of: "http://",  with: "")
                                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                    detailRow(icon: "globe", iconColor: .zenLavender,
                                              text: display, actionLabel: "Visit") {
                                        if let u = URL(string: web) { UIApplication.shared.open(u) }
                                    }
                                }
                                if detail?.phoneNumber == nil && detail?.websiteURL == nil {
                                    Text("No additional contact info available.\nSee Google Maps for more details.")
                                        .font(ZenFont.caption(13)).foregroundColor(.zenSubtext)
                                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                            }
                        }

                        Button { vm.openInMaps(therapist) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                Text("Get Directions").font(ZenFont.heading(16))
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(
                                colors: [.zenPurple, Color(red: 0.65, green: 0.45, blue: 0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: .top)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white, Color.black.opacity(0.35))
            }
            .padding(.top, 52).padding(.trailing, 20)
        }
        .task {
            detail    = await vm.fetchDetails(for: therapist.id)
            isLoading = false
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, iconColor: Color, text: String,
                           actionLabel: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconColor).frame(width: 24)
            Text(text).font(ZenFont.body(14)).foregroundColor(.zenText).lineLimit(3).multilineTextAlignment(.leading)
            Spacer()
            Button(action: action) {
                Text(actionLabel).font(ZenFont.caption(12)).foregroundColor(.zenPurple)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.zenLavender.opacity(0.30)).clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(14).background(Color.white.opacity(0.72)).cornerRadius(12)
        .shadow(color: .zenDusk.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder
    private func detailInfoRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(iconColor).frame(width: 24)
            Text(text).font(ZenFont.body(14)).foregroundColor(.zenText)
            Spacer()
        }
        .padding(14).background(Color.white.opacity(0.72)).cornerRadius(12)
        .shadow(color: .zenDusk.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TherapistFinderView()
            .environmentObject(SubscriptionManager())
    }
}
