//
//  ConcertShow.swift
//  BeatsWall
//
//  Concert Mode: follows the song playing in Music or Spotify, lights the stage in its album
//  art's colors, puts its name on the screens and picks the stage that suits it.
//

import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// How the stage looks for one song.
struct SongLook {
    var title: String
    var artist: String
    /// Stage light colors, from the album art.
    var colors: [Color]
    /// When the song started, for the "now playing" moment.
    var startedAt: Date
}

enum ArtworkPalette {
    /// The most common vivid colors in an image, pushed bright so they read as stage lights.
    /// Nil for black and white or washed-out images.
    static func colors(from image: CGImage) -> [Color]? {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        // Twelve hue buckets, weighted toward saturated, bright pixels.
        var weight = [Double](repeating: 0, count: 12)
        var hueX = [Double](repeating: 0, count: 12)
        var hueY = [Double](repeating: 0, count: 12)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = NSColor(
                srgbRed: CGFloat(pixels[index]) / 255, green: CGFloat(pixels[index + 1]) / 255,
                blue: CGFloat(pixels[index + 2]) / 255, alpha: 1
            )
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            guard saturation > 0.25, brightness > 0.2 else { continue }
            let bucket = min(Int(hue * 12), 11)
            let amount = Double(saturation * brightness)
            weight[bucket] += amount
            hueX[bucket] += cos(Double(hue) * 2 * .pi) * amount
            hueY[bucket] += sin(Double(hue) * 2 * .pi) * amount
        }
        let minimum = Double(side * side) * 0.02
        let picks = weight.indices.filter { weight[$0] > minimum }.sorted { weight[$0] > weight[$1] }.prefix(4)
        guard !picks.isEmpty else { return nil }
        var hues = picks.map { bucket -> Double in
            let angle = atan2(hueY[bucket], hueX[bucket]) / (2 * .pi)
            return angle < 0 ? angle + 1 : angle
        }
        // A one-color cover still gets a little variety: a neighbor and a contrasting accent.
        if hues.count == 1 { hues += [hues[0] + 0.08, hues[0] + 0.5] }
        if hues.count == 2 { hues.append(hues[0] + 0.5) }
        return hues.map { Color(hue: $0.truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 1) }
    }

    /// Colors made from a song's name, so a song without usable art still gets its own look.
    static func colors(seed: String) -> [Color] {
        var hash: UInt64 = 5381
        for byte in seed.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        let base = Double(hash % 360) / 360
        return [base, base + 0.33, base + 0.62].map { Color(hue: $0.truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 1) }
    }
}

@Observable
final class ConcertShow {
    enum Status: Equatable {
        case idle
        case listening
        case playing
        case needsPermission(String)
    }

    static let stages = ["concert.main-stage", "concert.headliner", "concert.lights-up", "concert.laser-rave"]

    private(set) var status = Status.idle
    private(set) var track: NowPlaying?
    private(set) var look: SongLook?
    private(set) var stageID = "concert.main-stage"

    @ObservationIgnored private let reader = NowPlayingReader()
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var sampleTimer: Timer?
    @ObservationIgnored private weak var lyrics: LyricsController?
    @ObservationIgnored private var readAudio: (() -> AudioFeatures)?
    @ObservationIgnored private var artworkColors: [String: [Color]] = [:]
    @ObservationIgnored private var listening = Listening()
    @ObservationIgnored private var quietFor = 0.0

    /// What the music has sounded like since the song started.
    private struct Listening {
        var seconds = 0.0
        var heard = 0.0
        var bpm = 0.0
        var bpmSamples = 0.0
        var level = 0.0
        var bass = 0.0
        var highs = 0.0
        var picks = 0
        /// Set when the genre already decided the stage.
        var genreStage: String?
    }

    var isActive: Bool { pollTimer != nil }

    var stageName: String {
        WallpaperCatalog.wallpaper(id: stageID)?.name ?? "Main Stage"
    }

    /// One line for the menu bar and Settings.
    var summary: String {
        switch status {
        case .idle: "Off"
        case .listening: "Listening… · \(stageName)"
        case .playing: "\(track?.title ?? "") — \(track?.artist ?? "") · \(stageName)"
        case .needsPermission(let player): "Allow BeatsWall to see \(player) in Privacy & Security › Automation"
        }
    }

    func setActive(_ active: Bool, lyrics: LyricsController, audio: @escaping () -> AudioFeatures) {
        guard active != isActive else { return }
        if active {
            self.lyrics = lyrics
            readAudio = audio
            status = .listening
            listening = Listening()
            poll()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
        } else {
            pollTimer?.invalidate()
            sampleTimer?.invalidate()
            pollTimer = nil
            sampleTimer = nil
            status = .idle
            track = nil
            look = nil
        }
    }

    // MARK: - Following the song

    private func poll() {
        // Lyrics already ask the player every second; don't ask twice.
        if let lyrics, lyrics.isActive {
            if case .needsPermission(let player) = lyrics.status {
                apply(.failure(.notAuthorized(player == NowPlaying.Player.spotify.rawValue ? .spotify : .music)))
            } else {
                apply(.success(lyrics.track))
            }
            return
        }
        reader.read { [weak self] result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(result) }
            }
        }
    }

    private func apply(_ result: Result<NowPlaying?, NowPlayingError>) {
        guard isActive else { return }
        switch result {
        case .failure(.notAuthorized(let player)):
            status = .needsPermission(player.rawValue)
            track = nil
            look = nil
        case .success(nil):
            status = .listening
            track = nil
            look = nil
        case .success(let info?):
            status = .playing
            let changed = info.trackKey != track?.trackKey
            track = info
            if changed { start(info) }
        }
    }

    private func start(_ info: NowPlaying) {
        let key = info.trackKey
        look = SongLook(
            title: info.title, artist: info.artist,
            colors: artworkColors[key] ?? ArtworkPalette.colors(seed: key), startedAt: Date()
        )
        listening = Listening(genreStage: Self.stage(forGenre: info.genre))
        if let stage = listening.genreStage { stageID = stage }
        guard artworkColors[key] == nil else { return }
        Task {
            let data = await reader.artwork(from: info.player)
            let image = data.flatMap { NSImage(data: $0) }?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            guard let colors = image.flatMap(ArtworkPalette.colors(from:)) else { return }
            artworkColors[key] = colors
            if track?.trackKey == key { look?.colors = colors }
        }
    }

    // MARK: - Picking the stage

    static func stage(forGenre genre: String) -> String? {
        let genre = genre.lowercased()
        guard !genre.isEmpty else { return nil }
        if ["rock", "metal", "punk", "alternative", "grunge"].contains(where: { genre.contains($0) }) { return "concert.headliner" }
        if ["electronic", "dance", "house", "techno", "edm", "trance", "dubstep", "drum"].contains(where: { genre.contains($0) }) { return "concert.laser-rave" }
        if ["ballad", "acoustic", "singer", "classical", "ambient", "soundtrack"].contains(where: { genre.contains($0) }) { return "concert.lights-up" }
        return nil
    }

    private func sample() {
        guard let audio = readAudio?() else { return }
        listening.seconds += 0.5
        // Without a player to say so, a gap of silence means the next song is starting.
        if Double(audio.level) < 0.02 {
            quietFor += 0.5
            return
        }
        if track == nil, quietFor >= 2 {
            listening = Listening()
        }
        quietFor = 0
        listening.heard += 1
        if audio.bpm > 40 {
            listening.bpm += Double(audio.bpm)
            listening.bpmSamples += 1
        }
        listening.level += Double(audio.level)
        listening.bass += Double(audio.bass)
        listening.highs += Double(audio.mid + audio.treble) / 2
        // Decide once the song has settled in, then once more in case it started quiet.
        let due = listening.picks == 0 ? 8.0 : 20.0
        guard listening.genreStage == nil, listening.picks < 2, listening.seconds >= due, listening.heard >= 8 else { return }
        listening.picks += 1
        stageID = pickStage()
    }

    private func pickStage() -> String {
        let heard = max(listening.heard, 1)
        let bpm = listening.bpmSamples > 0 ? listening.bpm / listening.bpmSamples : 0
        let level = listening.level / heard
        let bass = listening.bass / heard
        let highs = listening.highs / heard
        if bpm > 0, bpm < 95, level < 0.45 { return "concert.lights-up" }
        if bpm >= 124, bass > 0.45 { return "concert.laser-rave" }
        if bass < 0.35, highs > bass * 1.3 { return "concert.headliner" }
        return "concert.main-stage"
    }
}

/// An image of the user's own that the concert stages show on their screens.
@Observable
final class StageImage {
    static let shared = StageImage()

    private(set) var image: CGImage?
    /// Light colors taken from the image, used when no song is setting them.
    private(set) var colors: [Color]?

    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeatsWall", isDirectory: true)
        return folder.appendingPathComponent("Stage Image.png")
    }

    private init() {
        if let source = CGImageSourceCreateWithURL(Self.fileURL as CFURL, nil) {
            show(CGImageSourceCreateImageAtIndex(source, 0, nil))
        }
    }

    /// Copies the picked image into the app's own storage, scaled down to screen size.
    func set(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: Self.fileURL, options: .atomic)
        show(image)
    }

    func clear() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        show(nil)
    }

    /// Asks the user for an image and puts it on the stage.
    func choose() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = "Choose an image for the concert stage screens."
        panel.prompt = "Put on Stage"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try set(from: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func show(_ image: CGImage?) {
        self.image = image
        colors = image.flatMap(ArtworkPalette.colors(from:))
    }
}
