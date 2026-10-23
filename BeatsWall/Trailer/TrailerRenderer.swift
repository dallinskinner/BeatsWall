//
//  TrailerRenderer.swift
//  BeatsWall
//
//  Debug-only: renders the app trailer to an MP4, frame by frame, from the real wallpapers.
//  Run with: BeatsWall -renderTrailer <audio> <out.mp4> [title] [artist] [--frames N]
//

#if DEBUG
import AVFoundation
import AppKit
import SwiftUI

enum TrailerRenderer {
    static let size = CGSize(width: 1920, height: 1080)
    static let fps = 30.0

    /// Returns true when the app was launched to render the trailer instead of running normally.
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
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
                lyrics.loadPreview(track: track, lines: lines, epoch: Date(timeIntervalSinceReferenceDate: 0))
                print("TRAILER: \(lines.count) synced lyric lines")
            } else {
                print("TRAILER: no synced lyrics found; the lyrics shot will show the title card")
                lyrics.loadPreview(track: track, lines: [], epoch: Date(timeIntervalSinceReferenceDate: 0))
            }
        }

        let source = OfflineAudioSource(frames: analysis.frames)
        let model = TrailerModel(timeline: timeline, source: source, lyrics: lyrics, songStart: songStart)
        // One persistent renderer, so wallpapers' simulations carry on from frame to frame.
        let renderer = ImageRenderer(content: TrailerView(model: model).frame(width: size.width, height: size.height))
        renderer.scale = 1

        let silentVideo = output.deletingLastPathComponent().appendingPathComponent(".beatswall-trailer-video.mp4")
        try? FileManager.default.removeItem(at: silentVideo)
        let writer = try AVAssetWriter(outputURL: silentVideo, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 18_000_000],
        ])
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: Int(size.width), height: Int(size.height))
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = min(frameLimit ?? Int(TrailerTimeline.length * fps), Int(TrailerTimeline.length * fps))
        for frame in 0..<totalFrames {
            model.time = Double(frame) / fps
            source.frameIndex = firstFrame + frame
            guard let image = renderer.cgImage else { continue }
            let pixels: CVMutablePixelBuffer
            if let pool = receiver.pixelBufferPool {
                pixels = try pool.makeMutablePixelBuffer()
            } else {
                pixels = try CVMutablePixelBuffer(attributes)
            }
            pixels.withUnsafeBuffer { draw(image, into: $0) }
            try await receiver.append(CVReadOnlyPixelBuffer(pixels), with: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
            if frame % 90 == 0 { print("TRAILER: frame \(frame)/\(totalFrames)") }
        }
        receiver.finish()
        await writer.finishWriting()
        if let error = writer.error { throw error }

        try await muxAudio(video: silentVideo, audio: audio, songStart: songStart, duration: Double(totalFrames) / fps, output: output)
        try? FileManager.default.removeItem(at: silentVideo)
    }

    private static func draw(_ image: CGImage, into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
    }

    /// Adds the matching slice of the song, with a short fade in and out.
    private static func muxAudio(video: URL, audio: URL, songStart: Double, duration: Double, output: URL) async throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: audio)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))

        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
        try audioTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: songStart, preferredTimescale: 600), duration: range.duration), of: sourceAudio, at: .zero)

        let fade = AVMutableAudioMixInputParameters(track: audioTrack)
        fade.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.5, preferredTimescale: 600)))
        fade.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: duration - 1.5, preferredTimescale: 600), duration: CMTime(seconds: 1.5, preferredTimescale: 600)))
        let mix = AVMutableAudioMix()
        mix.inputParameters = [fade]

        try? FileManager.default.removeItem(at: output)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        export.audioMix = mix
        try await export.export(to: output, as: .mp4)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
