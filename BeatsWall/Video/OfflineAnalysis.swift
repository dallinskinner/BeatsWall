//
//  OfflineAnalysis.swift
//  BeatsWall
//
//  Analyzes a whole song ahead of time so video can be rendered offline.
//

import AVFoundation
import Foundation

/// Audio features for every video frame of a song, plus its detected beats.
nonisolated struct SongAnalysis: Sendable {
    let fps: Double
    let duration: Double
    /// One entry per video frame across the whole song.
    let frames: [AudioFeatures]
    /// Song time (seconds) of every detected beat.
    let beats: [Double]

    /// The most energetic stretch of `length` seconds, starting on a beat.
    func loudestWindow(length: Double) -> Double {
        let count = Int(length * fps)
        guard frames.count > count else { return 0 }
        let scores = frames.map { Double($0.level + $0.bass) }
        var sum = scores[0..<count].reduce(0, +)
        var best = (start: 0, score: sum)
        for start in 1...(frames.count - count) {
            sum += scores[start + count - 1] - scores[start - 1]
            if sum > best.score { best = (start, sum) }
        }
        let start = Double(best.start) / fps
        // Snap back to the nearest beat so the trailer opens on the music.
        return beats.last { $0 <= start + 0.05 } ?? start
    }
}

nonisolated enum OfflineAnalysis {
    /// A clock the analyzer reads, advanced by hand as samples are fed in.
    nonisolated private final class VirtualClock: @unchecked Sendable {
        var time = 0.0
    }

    static func analyze(url: URL, fps: Double) throws -> SongAnalysis {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let clock = VirtualClock()
        let store = AudioFeaturesStore(clock: { clock.time })
        let analyzer = AudioAnalyzer(store: store, clock: { clock.time })

        let chunk: AVAudioFrameCount = 512
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var mono = [Float](repeating: 0, count: Int(chunk))
        var frames: [AudioFeatures] = []
        var beats: [Double] = []
        var lastBeatCount = 0
        var samplesRead: AVAudioFramePosition = 0

        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: chunk)
            let count = Int(buffer.frameLength)
            guard count > 0, let data = buffer.floatChannelData else { break }
            for index in 0..<count {
                var sum: Float = 0
                for channel in 0..<channels { sum += data[channel][index] }
                mono[index] = sum / Float(channels)
            }
            samplesRead += AVAudioFramePosition(count)
            clock.time = Double(samplesRead) / sampleRate
            mono.withUnsafeBufferPointer { pointer in
                analyzer.process(interleaved: pointer.baseAddress!, frames: count, channels: 1, sampleRate: sampleRate)
            }

            let snapshot = store.read()
            if snapshot.beatCount != lastBeatCount {
                lastBeatCount = snapshot.beatCount
                beats.append(clock.time - snapshot.secondsSinceBeat)
            }
            while Double(frames.count) / fps <= clock.time {
                frames.append(store.read())
            }
        }
        return SongAnalysis(fps: fps, duration: Double(file.length) / sampleRate, frames: frames, beats: beats)
    }
}

/// Plays back pre-analyzed features for whichever video frame is being rendered.
nonisolated final class OfflineAudioSource: AudioFeatureSource, @unchecked Sendable {
    private let frames: [AudioFeatures]
    var frameIndex = 0

    init(frames: [AudioFeatures]) {
        self.frames = frames
    }

    func read() -> AudioFeatures {
        frames[min(max(frameIndex, 0), frames.count - 1)]
    }
}
