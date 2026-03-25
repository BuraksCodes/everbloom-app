// APIProxy.swift
// Everbloom — Single source of truth for all OpenAI calls.
//
// The real OpenAI API key lives ONLY in the Cloudflare Worker's encrypted
// secrets (set via `wrangler secret put OPENAI_API_KEY`). This file never
// contains a live key — the app authenticates to the worker with a lightweight
// app token instead.
//
// Setup (one-time):
//   1. cd Everbloom/backend
//   2. npm install -g wrangler && wrangler login
//   3. wrangler secret put OPENAI_API_KEY   ← your sk-proj-… key
//   4. wrangler secret put APP_TOKEN        ← any strong random string
//   5. wrangler deploy
//   6. Paste the printed URL into `workerBaseURL` below.
//   7. Paste the same APP_TOKEN into `appToken` below.

import Foundation

enum APIProxy {

    // ── Configuration ─────────────────────────────────────────────────────
    // Replace these two values after running `wrangler deploy`.

    /// URL printed by `wrangler deploy`, e.g.
    /// "https://everbloom-api.yourname.workers.dev"
    static let workerBaseURL = "https://everbloom-api.everbloom-app.workers.dev"

    /// Must match the APP_TOKEN secret you set on the Worker.
    /// Rotate this string any time by updating the Worker secret and this value.
    static let appToken = "everbloom_Secret_2026()"

    // ── ElevenLabs Voice IDs ──────────────────────────────────────────────
    // Custom voices created in the Everbloom ElevenLabs account.
    // Update these if voices are replaced in the ElevenLabs dashboard.

    /// British female therapist voice (ElevenLabs)
    static let voiceFemale = "jzuZ6QJQWqhEeMcPjdjx"
    /// British male therapist voice (ElevenLabs)
    static let voiceMale   = "6B6YCww4SQbiIPwsnY3l"

    // ── TTS ───────────────────────────────────────────────────────────────

    /// Fetch synthesised speech via ElevenLabs through the Cloudflare proxy.
    /// - Parameters:
    ///   - phrase: Text to speak (emojis / special chars already stripped by caller).
    ///   - voice:  ElevenLabs voice ID — use `APIProxy.voiceFemale` or `APIProxy.voiceMale`.
    /// - Returns: URL of a written temp MP3, or nil on any error.
    static func fetchTTS(phrase: String, voice: String, speed: Double = 0.88) async -> URL? {
        guard let url = URL(string: "\(workerBaseURL)/tts") else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(appToken,           forHTTPHeaderField: "X-App-Token")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Note: ElevenLabs ignores "model" and "speed" — voice quality/style
        // is configured server-side in the worker's voice_settings.
        let body: [String: Any] = [
            "input": phrase,
            "voice": voice,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            // Write to a stable path keyed by content so concurrent calls
            // for the same phrase safely share the same file.
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("everbloom_tts_\(abs(phrase.hashValue)).mp3")
            try data.write(to: tmp)
            return tmp
        } catch {
            #if DEBUG
            print("[APIProxy] TTS fetch error: \(error)")
            #endif
            return nil
        }
    }

    // ── Chat ──────────────────────────────────────────────────────────────

    /// Build a URLRequest for a proxied chat-completion call.
    /// The body is forwarded as-is to OpenAI, so streaming (stream: true) works.
    static func makeChatRequest(body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "\(workerBaseURL)/chat") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(appToken,           forHTTPHeaderField: "X-App-Token")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    // ── Places (POST search / Text Search) ────────────────────────────────

    /// Build a URLRequest to POST a Google Places search through the proxy.
    /// - Parameters:
    ///   - placesURL: Full `https://places.googleapis.com/v1/...` endpoint URL.
    ///   - fieldMask: Comma-separated list of fields to return.
    ///   - body:      JSON body forwarded to the Places API.
    static func makePlacesRequest(placesURL: String,
                                  fieldMask: String,
                                  body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: "\(workerBaseURL)/places") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(appToken,            forHTTPHeaderField: "X-App-Token")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["url": placesURL, "fieldMask": fieldMask, "body": body]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return req
    }

    // ── Places (GET details) ───────────────────────────────────────────────

    /// Build a URLRequest to GET a single Place's details through the proxy.
    /// - Parameters:
    ///   - placesURL: Full `https://places.googleapis.com/v1/places/{id}` URL.
    ///   - fieldMask: Comma-separated fields to return.
    static func makePlacesGetRequest(placesURL: String,
                                     fieldMask: String) throws -> URLRequest {
        guard let url = URL(string: "\(workerBaseURL)/places") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(appToken,            forHTTPHeaderField: "X-App-Token")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        // Tell the worker to forward a GET to the Places API
        let payload: [String: Any] = ["url": placesURL, "fieldMask": fieldMask, "method": "GET"]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return req
    }

    // ── Places Photo ───────────────────────────────────────────────────────

    /// Fetch raw photo bytes for a Google Places photo through the proxy.
    /// - Parameters:
    ///   - photoName:  The `places/.../photos/...` name string from the Places API.
    ///   - maxWidthPx: Maximum image width in pixels (default 300).
    /// - Returns: Raw image `Data`, or `nil` on any error.
    static func fetchPlacesPhoto(photoName: String, maxWidthPx: Int = 300) async -> Data? {
        guard let url = URL(string: "\(workerBaseURL)/places/photo") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(appToken,            forHTTPHeaderField: "X-App-Token")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["photoName": photoName, "maxWidthPx": maxWidthPx]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return data
        } catch {
            #if DEBUG
            print("[APIProxy] Places photo fetch error: \(error)")
            #endif
            return nil
        }
    }
}
