// SoundDownloader.swift
// Everbloom — Downloads real ambient sounds from archive.org and caches them locally.
//
// How it works:
// 1. Calls the archive.org Metadata API (/metadata/{identifier}/files) to get a JSON
//    list of files in the archive without needing hardcoded filenames.
// 2. Finds the best matching MP3 (by keyword in filename or title).
// 3. Downloads and saves to Documents/CachedSounds/{name}.mp3.
// 4. AudioManager prefers cached files over synthesis; synthesis is the fallback.
//
// All archive.org items used are Public Domain / Creative Commons (no attribution needed).

import Foundation
import Combine

@MainActor
final class SoundDownloader: ObservableObject {

    static let shared = SoundDownloader()

    @Published var isDownloading: [String: Bool] = [:]
    @Published var cachedSounds:  Set<String>    = []

    private let cacheDir: URL

    // ── Archive.org sources per sound ──────────────────────────────────────────
    // Each entry lists one or more archive identifiers + a keyword used to pick the
    // right file from the directory listing. Multiple sources = automatic fallback.

    private struct Source {
        let id:      String   // archive.org item identifier
        let keyword: String   // substring to match in the MP3 filename/title
    }

    private let sources: [String: [Source]] = [
        "rain": [
            Source(id: "free-and-excellent-rain-sound-effect-gentle-and-relaxing-effect", keyword: "rain"),
            Source(id: "RainSoundsAndForestSounds",  keyword: "rain"),
            Source(id: "relaxingsounds",              keyword: "rain"),
        ],
        "ocean": [
            Source(id: "naturesounds-soundtheraphy",  keyword: "ocean"),
            Source(id: "relaxingsounds",              keyword: "ocean"),
            Source(id: "relaxingsounds",              keyword: "wave"),
        ],
        "forest": [
            Source(id: "ForestSounds",                keyword: "forest"),
            Source(id: "RainSoundsAndForestSounds",   keyword: "forest"),
            Source(id: "naturesounds-soundtheraphy",  keyword: "bird"),
        ],
        "whitenoise": [
            Source(id: "relaxingsounds",              keyword: "white"),
            Source(id: "relaxingsounds",              keyword: "noise"),
        ],
        "stream": [
            Source(id: "relaxingsounds",              keyword: "stream"),
            Source(id: "relaxingsounds",              keyword: "river"),
            Source(id: "relaxingsounds",              keyword: "water"),
        ],
        "windbells": [
            Source(id: "relaxingsounds",              keyword: "bell"),
            Source(id: "relaxingsounds",              keyword: "chime"),
            Source(id: "relaxingsounds",              keyword: "wind"),
        ],
    ]

    // MARK: - Init

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("CachedSounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        scanCache()
    }

    // MARK: - Public API

    /// URL of the cached file for a given sound name, or nil if not yet downloaded.
    func cachedURL(for name: String) -> URL? {
        let url = cacheDir.appendingPathComponent("\(name).mp3")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Trigger background download for all sounds not yet cached.
    func downloadAllIfNeeded() {
        for name in sources.keys where !cachedSounds.contains(name) {
            Task { await download(name) }
        }
    }

    /// Download a single sound and cache it. Safe to call multiple times.
    func download(_ name: String) async {
        guard !cachedSounds.contains(name), isDownloading[name] != true else { return }
        isDownloading[name] = true
        defer { isDownloading[name] = false }

        guard let sourcelist = sources[name] else { return }

        for source in sourcelist {
            if let data = await fetchBestMP3(from: source.id, keyword: source.keyword) {
                let dest = cacheDir.appendingPathComponent("\(name).mp3")
                do {
                    try data.write(to: dest)
                    cachedSounds.insert(name)
                    #if DEBUG
                    print("[SoundDownloader] ✓ \(name) cached (\(data.count / 1024) KB)")
                    #endif
                    return
                } catch {
                    print("[SoundDownloader] Write failed for \(name): \(error)")
                }
            }
        }
        #if DEBUG
        print("[SoundDownloader] ✗ All sources failed for \(name)")
        #endif
    }

    // MARK: - Private

    private func scanCache() {
        for name in sources.keys {
            if FileManager.default.fileExists(atPath: cacheDir.appendingPathComponent("\(name).mp3").path) {
                cachedSounds.insert(name)
            }
        }
    }

    /// Uses archive.org's Metadata API to discover the right MP3 filename at runtime —
    /// no hardcoded filenames needed. Then downloads and returns the raw audio bytes.
    private func fetchBestMP3(from identifier: String, keyword: String) async -> Data? {

        // Step 1: Fetch the file listing for this archive item
        guard let metaURL = URL(string: "https://archive.org/metadata/\(identifier)/files") else { return nil }

        do {
            let (metaData, metaResp) = try await URLSession.shared.data(from: metaURL)
            guard (metaResp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                  let files = json["result"] as? [[String: Any]] else { return nil }

            // Step 2: Find an MP3 whose filename/title contains our keyword
            let mp3Files = files.filter {
                ($0["format"] as? String)?.lowercased().contains("mp3") == true
            }

            let matched = mp3Files.first(where: {
                let name  = ($0["name"]  as? String ?? "").lowercased()
                let title = ($0["title"] as? String ?? "").lowercased()
                return name.contains(keyword) || title.contains(keyword)
            }) ?? mp3Files.first   // fallback: any MP3 in the archive

            guard let fileName = matched?["name"] as? String else { return nil }

            // Step 3: Download the file
            let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
            guard let dlURL = URL(string: "https://archive.org/download/\(identifier)/\(encoded)") else { return nil }

            #if DEBUG
            print("[SoundDownloader] Fetching \(keyword) from \(dlURL.lastPathComponent)")
            #endif
            let (fileData, dlResp) = try await URLSession.shared.data(from: dlURL)
            guard (dlResp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return fileData

        } catch {
            #if DEBUG
            print("[SoundDownloader] \(identifier)/\(keyword): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
