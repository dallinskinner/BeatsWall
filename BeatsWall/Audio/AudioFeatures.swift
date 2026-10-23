//
//  AudioFeatures.swift
//  BeatsWall
//

import Foundation

/// A snapshot of what the music is doing right now. Every value is normalized to 0...1
/// so wallpapers can map them straight onto visuals.
nonisolated struct AudioFeatures: Sendable {
    static let binCount = 32
    /// How quickly `beatPulse` decays after a beat, per second.
    static let beatDecay = 4.5

    /// Overall loudness.
    var level: Float = 0
    /// Low end (kicks, bass lines), roughly 20–150 Hz.
    var bass: Float = 0
    /// Vocals and most instruments, roughly 150 Hz–2 kHz.
    var mid: Float = 0
    /// Hats, cymbals and air, roughly 2–12 kHz.
    var treble: Float = 0
    /// Log-spaced spectrum from ~40 Hz to ~16 kHz.
    var spectrum = [Float](repeating: 0, count: AudioFeatures.binCount)
    /// 1 at the moment of a beat, decaying exponentially toward 0.
    var beatPulse: Float = 0
    /// Increments once per detected beat. Useful for stepping animations on the beat.
    var beatCount = 0
    /// Seconds since the last beat, or infinity if there hasn't been one.
    var secondsSinceBeat = Double.infinity
    /// Estimated tempo, or 0 when unknown.
    var bpm: Float = 0
}

extension AudioFeatures {
    /// Length of one beat in seconds, assuming 120 BPM until a tempo is known.
    var beatLength: Double {
        bpm > 40 ? 60 / Double(bpm) : 0.5
    }

    /// A continuously increasing beat clock: whole numbers land on beats. It holds briefly
    /// if a beat is late, and free-runs at the last tempo when beats stop, so tempo-locked
    /// motion never freezes in quiet passages.
    func beatProgress(at time: Double) -> Double {
        guard secondsSinceBeat.isFinite else { return time / beatLength }
        let fraction = secondsSinceBeat / beatLength
        let hold = 0.5
        if fraction <= 1 { return Double(beatCount) + fraction }
        if fraction <= 1 + hold { return Double(beatCount) + 1 }
        return Double(beatCount) + fraction - hold
    }
}

/// Anything wallpapers can pull audio features from: live system audio or a simulated beat.
/// `read()` is called once per rendered frame, from the main thread.
nonisolated protocol AudioFeatureSource: AnyObject, Sendable {
    func read() -> AudioFeatures
}

nonisolated func audioClock() -> Double {
    ProcessInfo.processInfo.systemUptime
}
