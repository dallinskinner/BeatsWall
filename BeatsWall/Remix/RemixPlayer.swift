//
//  RemixPlayer.swift
//  BeatsWall
//
//  Saved remixes, and playing one as a live show: the desktop changes stage for each section,
//  with each song's name and colors, following the remix's own analyzed beats.
//

import AVFoundation
import Observation
import SwiftUI

struct SavedRemix: Identifiable, Hashable {
    let folder: URL
    let plan: RemixPlan

    var id: String { folder.path }
    var audioURL: URL { folder.appendingPathComponent("remix.m4a") }

    static func == (lhs: SavedRemix, rhs: SavedRemix) -> Bool { lhs.folder == rhs.folder }
    func hash(into hasher: inout Hasher) { hasher.combine(folder) }
}

enum RemixLibrary {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeatsWall/Remixes", isDirectory: true)
    }

    /// Every saved remix, newest first.
    static func all() -> [SavedRemix] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("remix.json")),
                  let plan = try? decoder.decode(RemixPlan.self, from: data) else { return nil }
            return SavedRemix(folder: folder, plan: plan)
        }
        .sorted { $0.plan.created > $1.plan.created }
    }

    /// A new, unused folder named after the remix.
    static func newFolder(named name: String) -> URL {
        let base = name.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        var candidate = folder.appendingPathComponent(base.isEmpty ? "Remix" : base)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(number)")
            number += 1
        }
        return candidate
    }

    static func delete(_ remix: SavedRemix) {
        try? FileManager.default.removeItem(at: remix.folder)
    }

    /// Turns the tracks into engine input: previews downloaded, colors read and a stage chosen
    /// for each song so neighbors never share one.
    static func prepare(_ tracks: [RemixTrack]) async throws -> [RemixInput] {
        let rotation = ["concert.main-stage", "concert.laser-rave", "lightshow.spotlight-rig", "concert.headliner", "lightshow.laser-show", "lightshow.light-tunnel"]
        var inputs: [RemixInput] = []
        var previous = RemixEngine.introStage
        for (index, original) in tracks.enumerated() {
            var track = original
            let url: URL
            switch track.source {
            case .preview(let song): url = try await SongSearch.downloadPreview(song)
            case .file(let file): url = file
            }
            if track.colors.isEmpty { await track.loadColors() }
            var stage = track.stageID ?? ConcertShow.stage(forGenre: track.genre, song: track.title + track.artist) ?? rotation[index % rotation.count]
            if stage == previous, track.stageID == nil {
                stage = rotation[(rotation.firstIndex(of: stage).map { $0 + 1 } ?? index + 1) % rotation.count]
            }
            previous = stage
            inputs.append(RemixInput(url: url, title: track.title, artist: track.artist, colors: track.colors, stageID: stage, isPreview: track.isPreview))
        }
        return inputs
    }
}

/// The finished remix's analyzed features, read at the player's current time.
nonisolated final class RemixAudioSource: AudioFeatureSource, @unchecked Sendable {
    private let frames: [AudioFeatures]
    private let fps: Double
    /// Playback time in seconds. Only read on the main thread, where wallpapers draw.
    var time: () -> Double = { 0 }

    init(analysis: SongAnalysis) {
        frames = analysis.frames
        fps = analysis.fps
    }

    func read() -> AudioFeatures {
        guard !frames.isEmpty else { return AudioFeatures() }
        return frames[min(max(Int(time() * fps), 0), frames.count - 1)]
    }
}

@Observable
final class RemixPlayer {
    private(set) var remix: SavedRemix?
    private(set) var isPreparing = false
    private(set) var isPaused = false
    private(set) var sectionIndex = 0
    /// Called when the show starts or ends, so the app can hand the desktop over.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private(set) var source: RemixAudioSource?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var sectionStartedAt = Date()

    /// A remix is on: the desktop follows it.
    var isActive: Bool { remix != nil && source != nil }

    var section: RemixPlan.Section? {
        guard let sections = remix?.plan.sections, sections.indices.contains(sectionIndex) else { return nil }
        return sections[sectionIndex]
    }

    var wallpaperID: String? { section?.stageID }

    /// The current section's name and colors; a new section counts as a new song, so stages
    /// fire their moment on every transition.
    var look: SongLook? {
        guard let section else { return nil }
        let colors = section.colors.map { Color(hex: $0) }
        return SongLook(title: section.title, artist: section.artist, colors: colors.isEmpty ? ConcertTheme.rig : colors, startedAt: sectionStartedAt)
    }

    var summary: String {
        guard let remix else { return "" }
        if isPreparing { return "Getting \(remix.plan.name) ready…" }
        let part = section.map { $0.kind == .song ? $0.title : ($0.kind == .intro ? "Intro" : "Outro") } ?? ""
        return "\(remix.plan.name) · \(part)\(isPaused ? " (paused)" : "")"
    }

    func play(_ remix: SavedRemix) {
        stop()
        self.remix = remix
        isPreparing = true
        Task {
            do {
                let url = remix.audioURL
                let analysis = try await Task.detached(priority: .userInitiated) { try OfflineAnalysis.analyze(url: url, fps: 30) }.value
                guard self.remix == remix else { return }
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                let source = RemixAudioSource(analysis: analysis)
                source.time = { [weak player] in player?.currentTime ?? 0 }
                self.player = player
                self.source = source
                sectionIndex = 0
                sectionStartedAt = Date()
                isPreparing = false
                player.play()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick() }
                }
                onChange?()
            } catch {
                NSLog("BeatsWall: couldn't play remix: \(error)")
                stop()
            }
        }
    }

    func togglePause() {
        guard let player else { return }
        if isPaused { player.play() } else { player.pause() }
        isPaused.toggle()
    }

    func stop() {
        let wasActive = isActive
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        source = nil
        remix = nil
        isPreparing = false
        isPaused = false
        if wasActive { onChange?() }
    }

    private func tick() {
        guard let player, let sections = remix?.plan.sections else { return }
        if !player.isPlaying, !isPaused {
            stop()
            return
        }
        let time = player.currentTime
        let index = sections.lastIndex { $0.start <= time + 0.02 } ?? 0
        if index != sectionIndex {
            sectionIndex = index
            sectionStartedAt = Date()
        }
    }
}
