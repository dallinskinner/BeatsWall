//
//  VideoWriter.swift
//  BeatsWall
//
//  Renders a SwiftUI view frame by frame into an H.264 MP4, then adds a slice of a song.
//

import AVFoundation
import AppKit
import SwiftUI

enum VideoWriter {
    struct Job {
        var size: CGSize
        var fps: Double
        var frameCount: Int
        var output: URL
        var audio: URL
        /// Song time where the video starts.
        var audioStart: Double
    }

    /// `prepareFrame` is called before each frame is captured, to move the view to that frame.
    /// One persistent renderer is used, so wallpapers' simulations carry on from frame to frame.
    static func write(
        _ job: Job,
        view: some View,
        prepareFrame: (Int) -> Void,
        progress: (Double) -> Void
    ) async throws {
        let content = view.frame(width: job.size.width, height: job.size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        let silentVideo = FileManager.default.temporaryDirectory
            .appendingPathComponent("beatswall-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: silentVideo) }

        let writer = try AVAssetWriter(outputURL: silentVideo, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(job.size.width),
            AVVideoHeightKey: Int(job.size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitRate(for: job.size)],
        ])
        input.expectsMediaDataInRealTime = false

        let frame: (Int) -> CGImage? = { index in
            prepareFrame(index)
            // The renderer only notices model changes on a later run loop pass, so hand it the
            // content again to make it draw this frame now. Wallpaper state carries over.
            renderer.content = content
            return renderer.cgImage
        }
        let report: (Int) -> Void = { index in
            if index % 15 == 0 { progress(Double(index) / Double(job.frameCount)) }
        }
        if #available(macOS 26, *) {
            try await writeFrames(job, writer: writer, input: input, frame: frame, report: report)
        } else {
            try await writeFramesLegacy(job, writer: writer, input: input, frame: frame, report: report)
        }
        await writer.finishWriting()
        if let error = writer.error { throw error }
        progress(1)

        try await muxAudio(video: silentVideo, job: job)
    }

    private static func bitRate(for size: CGSize) -> Int {
        // About 18 Mbps at 1080p, scaled by pixel count.
        Int(18_000_000 * (size.width * size.height) / (1920 * 1080))
    }

    @available(macOS 26, *)
    private static func writeFrames(
        _ job: Job, writer: AVAssetWriter, input: AVAssetWriterInput,
        frame: (Int) -> CGImage?, report: (Int) -> Void
    ) async throws {
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: Int(job.size.width), height: Int(job.size.height))
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)

        for index in 0..<job.frameCount {
            try Task.checkCancellation()
            guard let image = frame(index) else { continue }
            let pixels: CVMutablePixelBuffer
            if let pool = receiver.pixelBufferPool {
                pixels = try pool.makeMutablePixelBuffer()
            } else {
                pixels = try CVMutablePixelBuffer(attributes)
            }
            pixels.withUnsafeBuffer { draw(image, into: $0) }
            try await receiver.append(CVReadOnlyPixelBuffer(pixels), with: time(of: index, fps: job.fps))
            report(index)
        }
        receiver.finish()
    }

    /// The pixel buffer adaptor path, for macOS before 26.
    private static func writeFramesLegacy(
        _ job: Job, writer: AVAssetWriter, input: AVAssetWriterInput,
        frame: (Int) -> CGImage?, report: (Int) -> Void
    ) async throws {
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(job.size.width),
            kCVPixelBufferHeightKey as String: Int(job.size.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        for index in 0..<job.frameCount {
            try Task.checkCancellation()
            guard let image = frame(index) else { continue }
            var buffer: CVPixelBuffer?
            if let pool = adaptor.pixelBufferPool {
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            }
            guard let buffer else { throw CocoaError(.fileWriteUnknown) }
            draw(image, into: buffer)
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            guard adaptor.append(buffer, withPresentationTime: time(of: index, fps: job.fps)) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
            report(index)
        }
        input.markAsFinished()
    }

    private static func time(of frame: Int, fps: Double) -> CMTime {
        CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
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
    private static func muxAudio(video: URL, job: Job) async throws {
        let duration = Double(job.frameCount) / job.fps
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: job.audio)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))

        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
        try audioTrack.insertTimeRange(
            CMTimeRange(start: CMTime(seconds: job.audioStart, preferredTimescale: 600), duration: range.duration),
            of: sourceAudio, at: .zero
        )

        let fade = AVMutableAudioMixInputParameters(track: audioTrack)
        fade.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.5, preferredTimescale: 600)))
        fade.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: duration - 1.5, preferredTimescale: 600), duration: CMTime(seconds: 1.5, preferredTimescale: 600)))
        let mix = AVMutableAudioMix()
        mix.inputParameters = [fade]

        try? FileManager.default.removeItem(at: job.output)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        export.audioMix = mix
        try await export.export(to: job.output, as: .mp4)
    }
}
