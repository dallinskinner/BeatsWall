//
//  TrailerRenderer.swift
//  BeatsWall
//
//  Debug-only: renders the app trailer to an MP4, frame by frame, from the real wallpapers.
//  Run with: BeatsWall -renderTrailer <audio> <out.mp4> [title] [artist] [--frames N]
//

#if DEBUG
import AppKit
import SwiftUI

enum TrailerRenderer {
    static let size = CGSize(width: 1920, height: 1080)
    static let fps = 30.0

    /// Returns true when the app was launched to render the trailer instead of running normally.
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "-renderClip"), arguments.count > flag + 4 {
            // -renderClip <audio> <out> <wallpaper id> <vertical|landscape|square> [--shuffle] [--handle name] [--rig settings]
            var settings = ClipSettings(wallpaperID: arguments[flag + 3])
            settings.song = URL(fileURLWithPath: arguments[flag + 1])
            settings.format = ClipSettings.Format(rawValue: arguments[flag + 4]) ?? .vertical
            settings.shuffles = arguments.contains("--shuffle")
            if let index = arguments.firstIndex(of: "--handle"), arguments.count > index + 1 {
                settings.handle = arguments[index + 1]
            }
            // e.g. --rig "colors=ice,pattern=cone,strobe=off,movement=chase,fog=0.8"
            if let index = arguments.firstIndex(of: "--rig"), arguments.count > index + 1 {
                for pair in arguments[index + 1].split(separator: ",") {
                    let parts = pair.split(separator: "=").map(String.init)
                    guard parts.count == 2 else { continue }
                    switch parts[0] {
                    case "colors": settings.rig.colors = LightRig.Colors(rawValue: parts[1]) ?? settings.rig.colors
                    case "pattern": settings.rig.pattern = LightRig.Pattern(rawValue: parts[1]) ?? settings.rig.pattern
                    case "strobe": settings.rig.strobe = LightRig.Strobe(rawValue: parts[1]) ?? settings.rig.strobe
                    case "movement": settings.rig.movement = LightRig.Movement(rawValue: parts[1]) ?? settings.rig.movement
                    case "intensity": settings.rig.intensity = Double(parts[1]) ?? settings.rig.intensity
                    case "fog": settings.rig.fog = Double(parts[1]) ?? settings.rig.fog
                    case "speed": settings.rig.speed = Double(parts[1]) ?? settings.rig.speed
                    default: break
                    }
                }
            }
            let output = URL(fileURLWithPath: arguments[flag + 2])
            Task { @MainActor in
                do {
                    try await ClipExporter().render(settings, song: settings.song!, output: output)
                    print("TRAILER: wrote \(output.path)")
                } catch {
                    print("TRAILER: failed: \(error)")
                }
                NSApp.terminate(nil)
            }
            return true
        }
        if let flag = arguments.firstIndex(of: "-renderRemix"), arguments.count > flag + 2 {
            // -renderRemix <remix folder> <out.mp4>: the live show of a saved remix, as video.
            let folder = URL(fileURLWithPath: arguments[flag + 1])
            let output = URL(fileURLWithPath: arguments[flag + 2])
            Task { @MainActor in
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let plan = try decoder.decode(RemixPlan.self, from: Data(contentsOf: folder.appendingPathComponent("remix.json")))
                    let audio = folder.appendingPathComponent("remix.m4a")
                    let analysis = try OfflineAnalysis.analyze(url: audio, fps: fps)
                    let source = OfflineAudioSource(frames: analysis.frames)
                    let model = ClipModel(wallpaperID: plan.sections[0].stageID, length: plan.duration, source: source, lyrics: nil, songStart: 0, showsWatermark: false)
                    let job = VideoWriter.Job(size: size, fps: fps, frameCount: Int(plan.duration * fps), output: output, audio: audio, audioStart: 0)
                    model.shotIndex = -1
                    try await VideoWriter.write(job, view: ClipView(model: model)) { frame in
                        let time = Double(frame) / fps
                        model.time = time
                        source.frameIndex = frame
                        let index = plan.sections.lastIndex { $0.start <= time + 0.001 } ?? 0
                        guard index != model.shotIndex else { return }
                        let section = plan.sections[index]
                        model.shotIndex = index
                        model.wallpaperID = section.stageID
                        model.look = SongLook(title: section.title, artist: section.artist, colors: section.colors.map { Color(hex: $0) }, startedAt: Date(timeIntervalSinceReferenceDate: section.start))
                    } progress: { _ in }
                    print("REMIX: wrote \(output.path)")
                } catch {
                    print("REMIX: failed: \(error)")
                }
                NSApp.terminate(nil)
            }
            return true
        }
        if let flag = arguments.firstIndex(of: "-buildRemix"), arguments.count > flag + 2 {
            // -buildRemix <out folder> <audio file or "search:term">…
            let folder = URL(fileURLWithPath: arguments[flag + 1])
            let items = Array(arguments.dropFirst(flag + 2)).filter { !$0.hasPrefix("-") }
            Task { @MainActor in
                do {
                    var tracks: [RemixTrack] = []
                    for item in items {
                        if item.hasPrefix("search:") {
                            guard let song = try await SongSearch.search(String(item.dropFirst(7))).first else { continue }
                            print("REMIX: found \(song.trackName) — \(song.artistName) (\(song.primaryGenreName ?? "?"))")
                            tracks.append(RemixTrack(song: song))
                        } else {
                            let url = URL(fileURLWithPath: item)
                            let info = await ClipExporter.songInfo(for: url)
                            tracks.append(RemixTrack(file: url, title: info.title, artist: info.artist ?? ""))
                        }
                    }
                    let inputs = try await RemixLibrary.prepare(tracks)
                    let name = folder.lastPathComponent
                    let plan = try await Task.detached {
                        try RemixEngine.build(inputs, name: name, folder: folder) { stage, _ in print("REMIX: \(stage)") }
                    }.value
                    print(String(format: "REMIX: %.1f BPM, %.1fs", plan.bpm, plan.duration))
                    for section in plan.sections {
                        print(String(format: "REMIX:   %6.2f–%6.2f  %@  %@  %@", section.start, section.end, section.kind.rawValue, section.title, section.stageID))
                    }
                } catch {
                    print("REMIX: failed: \(error)")
                }
                NSApp.terminate(nil)
            }
            return true
        }
        guard let flag = arguments.firstIndex(of: "-renderTrailer"), arguments.count > flag + 2 else { return false }
        let audio = URL(fileURLWithPath: arguments[flag + 1])
        let output = URL(fileURLWithPath: arguments[flag + 2])
        let extras = Array(arguments.dropFirst(flag + 3))
        let title = extras.first { !$0.hasPrefix("--") }
        let artist = extras.dropFirst().first { !$0.hasPrefix("--") }
        let frameLimit = extras.firstIndex(of: "--frames").flatMap { Int(extras[safe: $0 + 1] ?? "") }

        Task { @MainActor in
            do {
                try await render(audio: audio, output: output, title: title, artist: artist, frameLimit: frameLimit)
                print("TRAILER: wrote \(output.path)")
            } catch {
                print("TRAILER: failed: \(error)")
            }
            NSApp.terminate(nil)
        }
        return true
    }

    @MainActor
    static func render(audio: URL, output: URL, title: String?, artist: String?, frameLimit: Int?) async throws {
        print("TRAILER: analyzing \(audio.lastPathComponent)…")
        let analysis = try OfflineAnalysis.analyze(url: audio, fps: fps)
        let songStart = analysis.loudestWindow(length: TrailerTimeline.length)
        let firstFrame = Int((songStart * fps).rounded())
        print(String(format: "TRAILER: %.1fs song, %d beats, using %.2fs–%.2fs", analysis.duration, analysis.beats.count, songStart, songStart + TrailerTimeline.length))

        let timeline = TrailerTimeline(beats: analysis.beats.map { $0 - songStart })
        for shot in timeline.shots {
            print(String(format: "TRAILER:   %6.2f–%6.2f  %@", shot.start, shot.end, "\(shot.kind) \(shot.wallpaperID)"))
        }

        let lyrics = LyricsController()
        if let title, let artist {
            let track = NowPlaying(player: .spotify, title: title, artist: artist, album: "", duration: analysis.duration, position: 0, isPlaying: true)
            if case .synced(let lines) = try? await LyricsService.lyrics(for: track) {
                lyrics.loadFixed(track: track, lines: lines, epoch: Date(timeIntervalSinceReferenceDate: 0))
                print("TRAILER: \(lines.count) synced lyric lines")
            } else {
                print("TRAILER: no synced lyrics found; the lyrics shot will show the title card")
                lyrics.loadFixed(track: track, lines: [], epoch: Date(timeIntervalSinceReferenceDate: 0))
            }
        }

        let source = OfflineAudioSource(frames: analysis.frames)
        let model = TrailerModel(timeline: timeline, source: source, lyrics: lyrics, songStart: songStart)
        let totalFrames = min(frameLimit ?? Int(TrailerTimeline.length * fps), Int(TrailerTimeline.length * fps))
        let job = VideoWriter.Job(size: size, fps: fps, frameCount: totalFrames, output: output, audio: audio, audioStart: songStart)
        try await VideoWriter.write(job, view: TrailerView(model: model)) { frame in
            model.time = Double(frame) / fps
            source.frameIndex = firstFrame + frame
        } progress: { fraction in
            if Int(fraction * 100) % 10 == 0 { print("TRAILER: \(Int(fraction * 100))%") }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
