//
//  LyricsController.swift
//  BeatsWall
//

import Foundation
import Observation

/// Follows the playing song and keeps its synced lyrics ready for the overlay.
@Observable
final class LyricsController {
    enum Status: Equatable {
        case idle
        case nothingPlaying
        case searching
        case showing
        case instrumental
        case notFound
        case needsPermission(String)
        case failed
    }

    private(set) var status: Status = .idle
    private(set) var track: NowPlaying?
    private(set) var lines: [LyricLine] = []

    @ObservationIgnored private let reader = NowPlayingReader()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var cache: [String: LyricsResult] = [:]
    @ObservationIgnored private var fetchingKey: String?
    /// When `track.position` was read, so playback position can be interpolated every frame.
    @ObservationIgnored private var readAt = Date()

    var isActive: Bool { timer != nil }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if active {
            poll()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
        } else {
            timer?.invalidate()
            timer = nil
            status = .idle
            track = nil
            lines = []
        }
    }

    /// Current playback position in seconds, interpolated since the last read.
    func position(at date: Date = Date()) -> Double? {
        guard let track else { return nil }
        return track.isPlaying ? track.position + date.timeIntervalSince(readAt) : track.position
    }

    /// The line being sung, the next line, and how far through the current line we are (0...1).
    func lyric(at date: Date = Date()) -> (current: LyricLine, next: LyricLine?, progress: Double)? {
        guard status == .showing, let position = position(at: date),
              let index = lines.lastIndex(where: { $0.time <= position }) else { return nil }
        let current = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1] : nil
        let end = next?.time ?? current.time + 4
        let progress = min(max((position - current.time) / max(end - current.time, 0.1), 0), 1)
        return (current, next, progress)
    }

    private func poll() {
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
        case .success(nil):
            status = .nothingPlaying
            track = nil
        case .success(let info?):
            let changed = info.trackKey != track?.trackKey
            track = info
            readAt = Date()
            if changed { load(info) }
        }
    }

    private func load(_ info: NowPlaying) {
        lines = []
        if let cached = cache[info.trackKey] {
            show(cached)
            return
        }
        status = .searching
        fetchingKey = info.trackKey
        Task {
            let result: LyricsResult?
            do {
                result = try await LyricsService.lyrics(for: info)
            } catch {
                result = nil
            }
            // Ignore answers for a song that's no longer playing.
            guard fetchingKey == info.trackKey, track?.trackKey == info.trackKey else { return }
            fetchingKey = nil
            if let result {
                cache[info.trackKey] = result
                show(result)
            } else {
                status = .failed
            }
        }
    }

    private func show(_ result: LyricsResult) {
        switch result {
        case .synced(let synced):
            lines = synced
            status = .showing
        case .instrumental:
            status = .instrumental
        case .notFound:
            status = .notFound
        }
    }
}

#if DEBUG
extension LyricsController {
    /// Loads sample lyrics without a player, for previews and visual checks.
    func loadPreview(track: NowPlaying, lines: [LyricLine]) {
        self.track = track
        self.lines = lines
        readAt = Date()
        status = .showing
    }
}
#endif
