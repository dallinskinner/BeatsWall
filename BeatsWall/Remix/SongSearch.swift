//
//  SongSearch.swift
//  BeatsWall
//
//  Finds songs in the Apple Music catalog through Apple's public iTunes Search API. Streamed
//  Apple Music audio is protected, so catalog songs are mixed from their 30-second previews.
//

import AppKit
import Foundation
import SwiftUI

nonisolated struct CatalogSong: Decodable, Identifiable, Hashable, Sendable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let primaryGenreName: String?
    let artworkUrl100: URL?
    let previewUrl: URL?

    var id: Int { trackId }

    /// The 600×600 version of the album art.
    var artworkURL: URL? {
        artworkUrl100.flatMap { URL(string: $0.absoluteString.replacingOccurrences(of: "100x100", with: "600x600")) }
    }
}

nonisolated enum SongSearch {
    private struct Response: Decodable {
        let results: [CatalogSong]
    }

    static func search(_ term: String) async throws -> [CatalogSong] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "25"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(Response.self, from: data).results.filter { $0.previewUrl != nil }
    }

    /// The song's 30-second preview, downloaded once and kept in the caches folder.
    static func downloadPreview(_ song: CatalogSong) async throws -> URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeatsWall/Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("\(song.trackId).m4a")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        guard let url = song.previewUrl else { throw URLError(.fileDoesNotExist) }
        let (download, _) = try await URLSession.shared.download(from: url)
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: download, to: file)
        return file
    }
}

/// One song in a remix, ready to mix.
struct RemixTrack: Identifiable, Hashable {
    enum Source: Hashable {
        case preview(CatalogSong)
        case file(URL)
    }

    let id = UUID()
    var source: Source
    var title: String
    var artist: String
    var genre: String
    /// Stage light colors from the album art, as 0xRRGGBB.
    var colors: [UInt32] = []
    /// A stage to use for this song's part, or nil to pick one automatically.
    var stageID: String?

    var isPreview: Bool {
        if case .preview = source { return true }
        return false
    }

    init(song: CatalogSong) {
        source = .preview(song)
        title = song.trackName
        artist = song.artistName
        genre = song.primaryGenreName ?? ""
    }

    init(file: URL, title: String, artist: String) {
        source = .file(file)
        self.title = title
        self.artist = artist
        genre = ""
    }

    /// Fills in light colors from the album art: downloaded for catalog songs, embedded for files.
    mutating func loadColors() async {
        var image: CGImage?
        switch source {
        case .preview(let song):
            if let url = song.artworkURL, let data = try? await URLSession.shared.data(from: url).0 {
                image = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        case .file(let url):
            image = await ClipExporter.songInfo(for: url).artwork
        }
        let palette = image.flatMap(ArtworkPalette.colors(from:)) ?? ArtworkPalette.colors(seed: title + artist)
        colors = palette.map(\.hexValue)
    }
}

extension Color {
    /// 0xRRGGBB in sRGB.
    var hexValue: UInt32 {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return 0xFFFFFF }
        let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return channel(rgb.redComponent) << 16 | channel(rgb.greenComponent) << 8 | channel(rgb.blueComponent)
    }
}
