//
//  ClipExporter.swift
//  BeatsWall
//
//  Records a wallpaper reacting to a song into a share-ready MP4, rendered offline frame by
//  frame so it's smooth however busy the Mac is.
//

import AVFoundation
import SwiftUI

struct ClipSettings {
    enum Format: String, CaseIterable, Identifiable {
        case vertical, landscape, square

        var id: String { rawValue }
        var title: String {
            switch self {
            case .vertical: "Vertical 9:16"
            case .landscape: "Landscape 16:9"
            case .square: "Square 1:1"
            }
        }
        var detail: String {
            switch self {
            case .vertical: "TikTok, Reels, Shorts"
            case .landscape: "YouTube, X"
            case .square: "Instagram feed"
            }
        }
        var size: CGSize {
            switch self {
            case .vertical: CGSize(width: 1080, height: 1920)
            case .landscape: CGSize(width: 1920, height: 1080)
            case .square: CGSize(width: 1080, height: 1080)
            }
        }
    }

    var wallpaperID: String
    /// Switch to another wallpaper from the same collection on every bar.
    var shuffles = false
    var song: URL?
    var length = 15.0
    /// Start at the most energetic part of the song rather than its beginning.
    var startsAtHighlight = true
    var format = Format.vertical
    var showsLyrics = true
    var showsWatermark = true
    /// The creator's handle for the watermark, without the @.
    var handle = ""
    /// Concert stages show the song's name and album art colors, from the file's tags.
    var showsSongOnStage = true
}

/// One frame of a clip: the wallpaper for that moment, lyrics and the watermark.
@Observable
final class ClipModel {
    var time = 0.0
    var shotIndex = 0
    var wallpaperID: String
    let length: Double
    let source: OfflineAudioSource
    let lyrics: LyricsController?
    let lyricsEpoch = Date(timeIntervalSinceReferenceDate: 0)
    let songStart: Double
    let showsWatermark: Bool
    let handle: String
    let look: SongLook?

    init(
        wallpaperID: String, length: Double, source: OfflineAudioSource, lyrics: LyricsController?, songStart: Double,
        showsWatermark: Bool, handle: String = "", look: SongLook? = nil
    ) {
        self.wallpaperID = wallpaperID
        self.length = length
        self.source = source
        self.lyrics = lyrics
        self.songStart = songStart
        self.showsWatermark = showsWatermark
        self.handle = handle
        self.look = look
    }
}

struct ClipView: View {
    let model: ClipModel

    var body: some View {
        let time = model.time
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            ZStack {
                if let wallpaper = WallpaperCatalog.wallpaper(id: model.wallpaperID) {
                    wallpaper
                        .makeView(WallpaperContext(source: model.source, isPaused: false, isPreview: false, renderTime: time, look: model.look))
                        .id(model.shotIndex)
                }
                if let lyrics = model.lyrics {
                    LyricsOverlay(
                        lyrics: lyrics, source: model.source, isPaused: false,
                        fixedDate: model.lyricsEpoch.addingTimeInterval(model.songStart + time)
                    )
                }
                if model.showsWatermark {
                    ClipWatermark(unit: unit, handle: model.handle)
                }
                // A quick fade up from black and down at the end.
                Color.black.opacity(max(1 - time / 0.3, max(0, (time - (model.length - 0.6)) / 0.6)))
            }
        }
    }
}

/// "Made with BeatsWall", tucked into the bottom corner, crediting the creator when they've
/// set a handle.
struct ClipWatermark: View {
    let unit: CGFloat
    var handle = ""

    /// "@name" from whatever the user typed, or nil if it's blank.
    static func credit(_ handle: String) -> String? {
        let name = handle.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return name.isEmpty ? nil : "@" + name
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: unit * 0.014) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: unit * 0.05, height: unit * 0.05)
                    if let credit = Self.credit(handle) {
                        Text("\(Text(credit).fontWeight(.heavy)) \(Text("· made with BeatsWall").fontWeight(.semibold).foregroundStyle(.white.opacity(0.8)))")
                            .font(.system(size: unit * 0.026, design: .rounded))
                    } else {
                        Text("BeatsWall")
                            .font(.system(size: unit * 0.03, weight: .heavy, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.leading, unit * 0.012)
                .padding(.trailing, unit * 0.022)
                .padding(.vertical, unit * 0.008)
                .background(.black.opacity(0.4), in: Capsule())
                .opacity(0.9)
            }
        }
        .padding(unit * 0.05)
    }
}

@Observable
final class ClipExporter {
    enum Status: Equatable {
        case idle
        case analyzing
        case rendering(Double)
        case finishing
        case done(URL)
        case failed(String)
    }

    static let fps = 30.0

    private(set) var status = Status.idle
    @ObservationIgnored private var task: Task<Void, Never>?

    var isBusy: Bool {
        switch status {
        case .analyzing, .rendering, .finishing: true
        default: false
        }
    }

    func export(_ settings: ClipSettings, to output: URL) {
        guard !isBusy, let song = settings.song else { return }
        status = .analyzing
        task = Task {
            do {
                try await render(settings, song: song, output: output)
                status = .done(output)
            } catch is CancellationError {
                status = .idle
                try? FileManager.default.removeItem(at: output)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
    }

    func reset() {
        if !isBusy { status = .idle }
    }

    func render(_ settings: ClipSettings, song: URL, output: URL) async throws {
        let accessing = song.startAccessingSecurityScopedResource()
        defer { if accessing { song.stopAccessingSecurityScopedResource() } }

        let fps = Self.fps
        let analysis = try await Task.detached(priority: .userInitiated) {
            try OfflineAnalysis.analyze(url: song, fps: fps)
        }.value
        try Task.checkCancellation()

        let length = min(settings.length, analysis.duration)
        let songStart = settings.startsAtHighlight ? analysis.loudestWindow(length: length) : 0
        let grid = BeatGrid(detectedBeats: analysis.beats.map { $0 - songStart }, length: length)

        let info = await Self.songInfo(for: song)
        let lyrics = settings.showsLyrics ? await Self.lyrics(for: info, duration: analysis.duration) : nil
        try Task.checkCancellation()
        let look = settings.showsSongOnStage ? info.look : nil

        let pool = shufflePool(for: settings)
        let source = OfflineAudioSource(frames: analysis.frames)
        let model = ClipModel(
            wallpaperID: settings.wallpaperID, length: length, source: source,
            lyrics: lyrics, songStart: songStart, showsWatermark: settings.showsWatermark,
            handle: settings.handle, look: look
        )
        let firstFrame = Int((songStart * fps).rounded())
        let job = VideoWriter.Job(
            size: settings.format.size, fps: fps, frameCount: Int(length * fps),
            output: output, audio: song, audioStart: songStart
        )

        status = .rendering(0)
        try await VideoWriter.write(job, view: ClipView(model: model)) { frame in
            let time = Double(frame) / fps
            model.time = time
            source.frameIndex = firstFrame + frame
            if settings.shuffles {
                // Bars that have started by now; the first stretch shows the chosen wallpaper.
                let bar = max(0, (grid.bars.lastIndex { $0 <= time + 0.001 } ?? -1))
                if bar != model.shotIndex {
                    model.shotIndex = bar
                    model.wallpaperID = pool[bar % pool.count]
                }
            }
        } progress: { [weak self] fraction in
            self?.status = fraction < 1 ? .rendering(fraction) : .finishing
        }
    }

    /// The chosen wallpaper first, then the rest of its collection in a shuffled order.
    private func shufflePool(for settings: ClipSettings) -> [String] {
        let collection = WallpaperCatalog.collections.first { $0.wallpapers.contains { $0.id == settings.wallpaperID } }
        let others = (collection?.wallpapers.map(\.id) ?? []).filter { $0 != settings.wallpaperID }.shuffled()
        return [settings.wallpaperID] + others
    }

    /// What the file says about itself: title and artist tags (or a title cleaned up from the
    /// file name) and its embedded album art.
    struct SongInfo {
        var title: String
        var artist: String?
        var artwork: CGImage?
        /// Whether the title came from tags rather than the file name.
        var isTagged: Bool

        var look: SongLook {
            let colors = artwork.flatMap(ArtworkPalette.colors(from:)) ?? ArtworkPalette.colors(seed: title + (artist ?? ""))
            return SongLook(title: title, artist: artist ?? "", colors: colors, startedAt: Date(timeIntervalSinceReferenceDate: 0))
        }
    }

    static func songInfo(for song: URL) async -> SongInfo {
        let tags = (try? await AVURLAsset(url: song).load(.commonMetadata)) ?? []
        func item(_ key: AVMetadataKey) -> AVMetadataItem? {
            AVMetadataItem.metadataItems(from: tags, withKey: key, keySpace: .common).first
        }
        let title = try? await item(.commonKeyTitle)?.load(.stringValue)
        let artist = try? await item(.commonKeyArtist)?.load(.stringValue)
        let artworkData = try? await item(.commonKeyArtwork)?.load(.dataValue)
        let artwork = artworkData.flatMap { NSImage(data: $0) }?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        if let title, let artist {
            return SongInfo(title: title, artist: artist, artwork: artwork, isTagged: true)
        }
        // "Song Name (Clean Edit).mp3" → "Song Name"
        let name = song.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return SongInfo(title: title ?? name, artist: artist, artwork: artwork, isTagged: false)
    }

    /// Synced lyrics from LRCLIB, found from the file's title and artist tags, or failing
    /// that its name.
    private static func lyrics(for info: SongInfo, duration: Double) async -> LyricsController? {
        let result: LyricsResult?
        let track: NowPlaying
        if info.isTagged, let artist = info.artist {
            track = NowPlaying(player: .spotify, title: info.title, artist: artist, album: "", duration: duration, position: 0, isPlaying: true)
            result = try? await LyricsService.lyrics(for: track)
        } else {
            track = NowPlaying(player: .spotify, title: info.title, artist: "", album: "", duration: duration, position: 0, isPlaying: true)
            result = try? await LyricsService.lyrics(searching: info.title, duration: duration)
        }
        guard case .synced(let lines) = result, !lines.isEmpty else { return nil }
        let controller = LyricsController()
        controller.loadFixed(track: track, lines: lines, epoch: Date(timeIntervalSinceReferenceDate: 0))
        return controller
    }
}
