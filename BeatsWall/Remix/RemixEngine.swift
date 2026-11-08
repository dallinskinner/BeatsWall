//
//  RemixEngine.swift
//  BeatsWall
//
//  Builds a remix from a list of songs: an intro from the first song, each song's best part
//  tempo-matched and crossfaded on the downbeat, and an echoing outro from the last song.
//

import Accelerate
import AVFoundation
import Foundation

/// A finished remix's sections, saved next to its audio as remix.json.
nonisolated struct RemixPlan: Codable, Sendable {
    struct Section: Codable, Sendable {
        enum Kind: String, Codable, Sendable { case intro, song, outro }

        var kind: Kind
        var trackIndex: Int
        /// Seconds into the remix.
        var start: Double
        var end: Double
        var title: String
        var artist: String
        /// Stage light colors, as 0xRRGGBB.
        var colors: [UInt32]
        var stageID: String
    }

    var name: String
    var bpm: Double
    var duration: Double
    var created: Date
    var sections: [Section]
}

/// One song as the engine needs it: a readable audio file and what to show for it.
nonisolated struct RemixInput: Sendable {
    var url: URL
    var title: String
    var artist: String
    var colors: [UInt32]
    /// The stage for this song's part, already chosen.
    var stageID: String
    /// 30-second previews give 8 bars; full songs give 16.
    var isPreview: Bool
}

nonisolated enum RemixEngine {
    static let sampleRate = 44_100.0
    static let introStage = "lightshow.fog-room"
    static let outroStage = "concert.lights-up"

    /// Stereo samples.
    struct Audio {
        var left: [Float] = []
        var right: [Float] = []
        var count: Int { left.count }
    }

    /// Where a piece comes from in its song, in that song's own seconds.
    private struct Piece {
        enum Kind { case intro, part, outro }
        var kind: Kind
        var track: Int
        var start: Double
        var bars: Int
    }

    private struct Timing {
        var beatLength: Double
        var anchor: Double
        var duration: Double
        var barLength: Double { beatLength * 4 }

        /// The bar line at or before `time`, never before the first beat.
        func barLine(atOrBefore time: Double) -> Double {
            max(anchor, anchor + ((time - anchor) / barLength).rounded(.down) * barLength)
        }
    }

    // MARK: - Building

    static func build(
        _ inputs: [RemixInput], name: String, folder: URL,
        progress: @escaping @Sendable (String, Double) -> Void
    ) throws -> RemixPlan {
        guard !inputs.isEmpty else { throw CocoaError(.featureUnsupported) }

        // Pass 1: listen to every song.
        var analyses: [SongAnalysis] = []
        var grids: [BeatGrid] = []
        for (index, input) in inputs.enumerated() {
            try Task.checkCancellation()
            progress("Listening to \(input.title)…", 0.4 * Double(index) / Double(inputs.count))
            let analysis = try OfflineAnalysis.analyze(url: input.url, fps: 30)
            analyses.append(analysis)
            grids.append(BeatGrid(detectedBeats: analysis.beats, length: analysis.duration))
        }

        // Everything plays at the median tempo, with each song counted at half, normal or
        // double time, whichever needs the least stretching.
        let folded = grids.map { grid -> Double in
            var bpm = 60 / grid.beatLength
            while bpm < 85 { bpm *= 2 }
            while bpm > 170 { bpm /= 2 }
            return bpm
        }.sorted()
        let bpm = folded[folded.count / 2]
        let timings = zip(grids, analyses).map { grid, analysis -> Timing in
            let raw = 60 / grid.beatLength
            let songBPM = [raw / 2, raw, raw * 2].min { abs(log(bpm / $0)) < abs(log(bpm / $1)) }!
            return Timing(beatLength: 60 / songBPM, anchor: grid.beats.first ?? 0, duration: analysis.duration)
        }

        // Which bars each piece uses.
        var pieces: [Piece] = []
        for (index, input) in inputs.enumerated() {
            let timing = timings[index]
            if index == 0 {
                pieces.append(Piece(kind: .intro, track: index, start: timing.anchor, bars: min(4, availableBars(timing, from: timing.anchor))))
            }
            // Its best part: the loudest stretch, starting on a bar line.
            var bars = input.isPreview ? 8 : 16
            let loudest = analyses[index].loudestWindow(length: min(Double(bars) * timing.barLength, timing.duration * 0.9))
            var start = timing.barLine(atOrBefore: loudest)
            if availableBars(timing, from: start) < bars {
                start = timing.barLine(atOrBefore: timing.duration - Double(bars) * timing.barLength)
            }
            bars = max(min(bars, availableBars(timing, from: start)), 1)
            pieces.append(Piece(kind: .part, track: index, start: start, bars: bars))
            if index == inputs.count - 1 {
                // The bars right after its part, so the outro keeps the energy and the echo
                // does the fading, not the song's own ending.
                var outroStart = start + Double(bars) * timing.barLength
                if availableBars(timing, from: outroStart) < 4 {
                    outroStart = max(timing.anchor, start - 4 * timing.barLength)
                }
                pieces.append(Piece(kind: .outro, track: index, start: outroStart, bars: max(min(4, availableBars(timing, from: outroStart)), 1)))
            }
        }

        let barSamples = Int((4 * 60 / bpm * sampleRate).rounded())

        // Pass 2: decode each song once, stretch its pieces to the shared tempo, and let it go.
        var rendered = [Audio](repeating: Audio(), count: pieces.count)
        for (track, input) in inputs.enumerated() {
            try Task.checkCancellation()
            progress("Matching the tempo of \(input.title)…", 0.4 + 0.4 * Double(track) / Double(inputs.count))
            let audio = try decode(input.url)
            let timing = timings[track]
            let rate = min(max(bpm * timing.beatLength / 60, 0.8), 1.25)
            for (index, piece) in pieces.enumerated() where piece.track == track {
                var stretched = try stretch(audio, from: piece.start, seconds: Double(piece.bars) * timing.barLength, rate: rate)
                // Snap the length to whole bars at the shared tempo so every join lands on a downbeat.
                fit(&stretched, to: piece.bars * barSamples)
                rendered[index] = stretched
            }
        }

        // Effects: the intro opens up from a muffled filter; each song filters in over its
        // first bar; the outro echoes and fades away.
        progress("Mixing…", 0.85)
        for (index, piece) in pieces.enumerated() {
            switch piece.kind {
            case .intro:
                sweep(&rendered[index], from: 250, to: 18_000, samples: rendered[index].count)
            case .part:
                if index > 0 { sweep(&rendered[index], from: 700, to: 18_000, samples: barSamples) }
            case .outro:
                echo(&rendered[index], delay: Int(0.75 * 60 / bpm * sampleRate), tail: barSamples)
                fadeOut(&rendered[index], samples: min(rendered[index].count, barSamples * 3))
            }
        }

        // Lay the pieces end to end, each overlapping the last by one bar with an equal-power
        // crossfade, and note where each section starts.
        var offsets: [Int] = []
        var cursor = 0
        for index in pieces.indices {
            let overlap = index == 0 ? 0 : min(barSamples, rendered[index - 1].count / 2, rendered[index].count / 2)
            cursor -= overlap
            offsets.append(cursor)
            if index > 0 { fadeIn(&rendered[index], samples: overlap, equalPower: true) }
            if index < pieces.count - 1 {
                let next = min(barSamples, rendered[index].count / 2, rendered[index + 1].count / 2)
                fadeOutEqualPower(&rendered[index], samples: next)
            }
            cursor += rendered[index].count
        }
        var mix = Audio(left: [Float](repeating: 0, count: cursor), right: [Float](repeating: 0, count: cursor))
        for index in pieces.indices {
            add(rendered[index], into: &mix, at: offsets[index])
        }
        normalize(&mix, peak: 0.891)

        // Sections change at the end of each crossfade, which is a downbeat.
        var sections: [RemixPlan.Section] = []
        for (index, piece) in pieces.enumerated() {
            let overlap = index == 0 ? 0 : min(barSamples, rendered[index - 1].count / 2, rendered[index].count / 2)
            let start = Double(offsets[index] + overlap) / sampleRate
            let input = inputs[piece.track]
            let section: RemixPlan.Section
            switch piece.kind {
            case .intro:
                section = .init(kind: .intro, trackIndex: piece.track, start: 0, end: 0, title: name, artist: "BeatsWall Remix", colors: input.colors, stageID: introStage)
            case .part:
                section = .init(kind: .song, trackIndex: piece.track, start: start, end: 0, title: input.title, artist: input.artist, colors: input.colors, stageID: input.stageID)
            case .outro:
                section = .init(kind: .outro, trackIndex: piece.track, start: start, end: 0, title: name, artist: "BeatsWall Remix", colors: input.colors, stageID: outroStage)
            }
            sections.append(section)
        }
        let duration = Double(mix.count) / sampleRate
        for index in sections.indices {
            sections[index].end = index + 1 < sections.count ? sections[index + 1].start : duration
        }

        progress("Saving…", 0.95)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write(mix, to: folder.appendingPathComponent("remix.m4a"))
        let plan = RemixPlan(name: name, bpm: bpm, duration: duration, created: Date(), sections: sections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(plan).write(to: folder.appendingPathComponent("remix.json"))
        progress("Done", 1)
        return plan
    }

    private static func availableBars(_ timing: Timing, from start: Double) -> Int {
        max(0, Int(((timing.duration - start) / timing.barLength).rounded(.down)))
    }

    // MARK: - Audio in and out

    /// The whole file as 44.1 kHz stereo floats.
    static func decode(_ url: URL) throws -> Audio {
        let file = try AVAudioFile(forReading: url)
        let source = file.processingFormat
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: input)
        let channels = min(source.channelCount, 2)
        guard let target = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels),
              let converter = AVAudioConverter(from: source, to: target) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let capacity = AVAudioFrameCount(Double(input.frameLength) * sampleRate / source.sampleRate) + 4096
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { throw CocoaError(.fileReadCorruptFile) }
        var delivered = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if delivered {
                status.pointee = .endOfStream
                return nil
            }
            delivered = true
            status.pointee = .haveData
            return input
        }
        if let error { throw error }
        let count = Int(output.frameLength)
        guard let data = output.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        let left = Array(UnsafeBufferPointer(start: data[0], count: count))
        let right = channels > 1 ? Array(UnsafeBufferPointer(start: data[1], count: count)) : left
        return Audio(left: left, right: right)
    }

    private static func write(_ audio: Audio, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 256_000,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let chunk = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(chunk)),
              let data = buffer.floatChannelData else { throw CocoaError(.fileWriteUnknown) }
        var position = 0
        while position < audio.count {
            let count = min(chunk, audio.count - position)
            audio.left.withUnsafeBufferPointer { data[0].update(from: $0.baseAddress! + position, count: count) }
            audio.right.withUnsafeBufferPointer { data[1].update(from: $0.baseAddress! + position, count: count) }
            buffer.frameLength = AVAudioFrameCount(count)
            try file.write(from: buffer)
            position += count
        }
    }

    // MARK: - Tempo

    /// `seconds` of audio from `start`, played `rate` times faster without changing pitch.
    private static func stretch(_ audio: Audio, from start: Double, seconds: Double, rate: Double) throws -> Audio {
        let first = max(0, min(audio.count, Int(start * sampleRate)))
        let last = max(first, min(audio.count, first + Int(seconds * sampleRate)))
        let slice = Audio(left: Array(audio.left[first..<last]), right: Array(audio.right[first..<last]))
        guard abs(rate - 1) > 0.003 else { return slice }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = Float(rate)
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        defer { engine.stop() }

        // Pad the end with silence so the stretcher flushes its last samples.
        let padding = Int(sampleRate * 0.5)
        guard let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(slice.count + padding)),
              let inputData = input.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        input.frameLength = AVAudioFrameCount(slice.count + padding)
        for channel in 0..<2 {
            let samples = channel == 0 ? slice.left : slice.right
            samples.withUnsafeBufferPointer { inputData[channel].update(from: $0.baseAddress!, count: samples.count) }
            (inputData[channel] + samples.count).update(repeating: 0, count: padding)
        }
        player.scheduleBuffer(input)
        player.play()

        // The stretcher starts a little late; skip that so beats stay on the grid.
        let latency = Int((timePitch.auAudioUnit.latency * sampleRate).rounded())
        let wanted = Int(Double(slice.count) / rate) + latency
        guard let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096),
              let outputData = output.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        var result = Audio()
        result.left.reserveCapacity(wanted)
        result.right.reserveCapacity(wanted)
        while result.count < wanted {
            let frames = AVAudioFrameCount(min(4096, wanted - result.count))
            switch try engine.renderOffline(frames, to: output) {
            case .success:
                let count = Int(output.frameLength)
                result.left.append(contentsOf: UnsafeBufferPointer(start: outputData[0], count: count))
                result.right.append(contentsOf: UnsafeBufferPointer(start: outputData[1], count: count))
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                continue
            case .error:
                throw CocoaError(.fileReadCorruptFile)
            @unknown default:
                throw CocoaError(.fileReadCorruptFile)
            }
        }
        if latency > 0, latency < result.count {
            result.left.removeFirst(latency)
            result.right.removeFirst(latency)
        }
        return result
    }

    /// Trims or pads with silence to exactly `count` samples.
    private static func fit(_ audio: inout Audio, to count: Int) {
        let difference = audio.count - count
        if difference > 0 {
            audio.left.removeLast(difference)
            audio.right.removeLast(difference)
        } else if difference < 0 {
            audio.left.append(contentsOf: [Float](repeating: 0, count: -difference))
            audio.right.append(contentsOf: [Float](repeating: 0, count: -difference))
        }
    }

    // MARK: - Effects

    /// A low-pass filter opening from `from` Hz to `to` Hz across the first `samples` samples.
    private static func sweep(_ audio: inout Audio, from: Double, to: Double, samples: Int) {
        let count = min(samples, audio.count)
        guard count > 1 else { return }
        var memory: (Float, Float) = (0, 0)
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            let cutoff = from * pow(to / from, progress)
            let amount = Float(1 - exp(-2 * .pi * cutoff / sampleRate))
            memory.0 += amount * (audio.left[index] - memory.0)
            memory.1 += amount * (audio.right[index] - memory.1)
            audio.left[index] = memory.0
            audio.right[index] = memory.1
        }
    }

    /// A feedback echo, with `tail` samples of silence added so it can ring out.
    private static func echo(_ audio: inout Audio, delay: Int, tail: Int) {
        guard delay > 0 else { return }
        audio.left.append(contentsOf: [Float](repeating: 0, count: tail))
        audio.right.append(contentsOf: [Float](repeating: 0, count: tail))
        for index in delay..<audio.count {
            audio.left[index] += 0.42 * audio.left[index - delay]
            audio.right[index] += 0.42 * audio.right[index - delay]
        }
    }

    private static func fadeIn(_ audio: inout Audio, samples: Int, equalPower: Bool) {
        let count = min(samples, audio.count)
        guard count > 0 else { return }
        for index in 0..<count {
            let t = Double(index) / Double(count)
            let gain = Float(equalPower ? sin(t * .pi / 2) : t)
            audio.left[index] *= gain
            audio.right[index] *= gain
        }
    }

    private static func fadeOutEqualPower(_ audio: inout Audio, samples: Int) {
        let count = min(samples, audio.count)
        guard count > 0 else { return }
        let first = audio.count - count
        for index in 0..<count {
            let gain = Float(cos(Double(index) / Double(count) * .pi / 2))
            audio.left[first + index] *= gain
            audio.right[first + index] *= gain
        }
    }

    /// A smooth fade to silence over the last `samples` samples.
    private static func fadeOut(_ audio: inout Audio, samples: Int) {
        let count = min(samples, audio.count)
        guard count > 0 else { return }
        let first = audio.count - count
        for index in 0..<count {
            let gain = Float(pow(1 - Double(index) / Double(count), 2))
            audio.left[first + index] *= gain
            audio.right[first + index] *= gain
        }
    }

    private static func add(_ audio: Audio, into mix: inout Audio, at offset: Int) {
        let count = min(audio.count, mix.count - offset)
        guard count > 0, offset >= 0 else { return }
        mix.left.withUnsafeMutableBufferPointer { out in
            audio.left.withUnsafeBufferPointer { vDSP_vadd(out.baseAddress! + offset, 1, $0.baseAddress!, 1, out.baseAddress! + offset, 1, vDSP_Length(count)) }
        }
        mix.right.withUnsafeMutableBufferPointer { out in
            audio.right.withUnsafeBufferPointer { vDSP_vadd(out.baseAddress! + offset, 1, $0.baseAddress!, 1, out.baseAddress! + offset, 1, vDSP_Length(count)) }
        }
    }

    /// Scales the mix so its loudest sample sits at `peak`.
    private static func normalize(_ audio: inout Audio, peak: Float) {
        var left: Float = 0
        var right: Float = 0
        vDSP_maxmgv(audio.left, 1, &left, vDSP_Length(audio.count))
        vDSP_maxmgv(audio.right, 1, &right, vDSP_Length(audio.count))
        let loudest = max(left, right)
        guard loudest > 0 else { return }
        var gain = peak / loudest
        let count = vDSP_Length(audio.count)
        audio.left.withUnsafeMutableBufferPointer { vDSP_vsmul($0.baseAddress!, 1, &gain, $0.baseAddress!, 1, count) }
        audio.right.withUnsafeMutableBufferPointer { vDSP_vsmul($0.baseAddress!, 1, &gain, $0.baseAddress!, 1, count) }
    }
}
