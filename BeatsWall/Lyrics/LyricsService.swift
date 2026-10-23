//
//  LyricsService.swift
//  BeatsWall
//

import Foundation

nonisolated struct LyricLine: Sendable, Equatable {
    /// Seconds into the track.
    var time: Double
    var text: String
}

nonisolated enum LyricsResult: Sendable {
    case synced([LyricLine])
    case instrumental
    case notFound
}

/// Time-synced lyrics from LRCLIB (https://lrclib.net), a free, open lyrics database.
nonisolated enum LyricsService {
    private static let base = URL(string: "https://lrclib.net/api")!

    static func lyrics(for track: NowPlaying) async throws -> LyricsResult {
        // Exact match first (uses duration to pick the right version), then a looser search.
        var exact = URLComponents(url: base.appendingPathComponent("get"), resolvingAgainstBaseURL: false)!
        exact.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded()))),
        ]
        if let record = try await fetch(exact.url!, as: Record.self), let result = record.result {
            return result
        }

        var search = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        search.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
        ]
        let records = try await fetch(search.url!, as: [Record].self) ?? []
        let best = records
            .filter { $0.syncedLyrics?.isEmpty == false }
            .min { abs(($0.duration ?? 0) - track.duration) < abs(($1.duration ?? 0) - track.duration) }
        if let best, let result = best.result { return result }
        if records.contains(where: { $0.instrumental == true }) { return .instrumental }
        return .notFound
    }

    private struct Record: Decodable {
        var duration: Double?
        var instrumental: Bool?
        var syncedLyrics: String?

        var result: LyricsResult? {
            if instrumental == true { return .instrumental }
            guard let syncedLyrics, !syncedLyrics.isEmpty else { return nil }
            let lines = LyricsService.parseLRC(syncedLyrics)
            return lines.isEmpty ? nil : .synced(lines)
        }
    }

    private static func fetch<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("BeatsWall/1.0 (macOS live wallpaper app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Parses LRC: `[mm:ss.xx]text`, possibly with several timestamps on one line.
    static func parseLRC(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let stamp = rest[rest.index(after: rest.startIndex)..<close]
                let parts = stamp.split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: close)...]
            }
            let words = rest.trimmingCharacters(in: .whitespaces)
            for time in times {
                lines.append(LyricLine(time: time, text: words))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }
}
