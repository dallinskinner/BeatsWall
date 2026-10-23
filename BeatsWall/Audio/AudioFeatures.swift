//
//  AudioFeatures.swift
//  BeatsWall
//

import Foundation

/// A snapshot of what the music is doing right now. Every value is normalized to 0...1
/// so wallpapers can map them straight onto visuals.
nonisolated struct AudioFeatures: Sendable {
    static let binCount = 32

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
    /// Estimated tempo, or 0 when unknown.
    var bpm: Float = 0
}

/// Anything wallpapers can pull audio features from: live system audio or a simulated beat.
/// `read()` is called once per rendered frame, from the main thread.
nonisolated protocol AudioFeatureSource: AnyObject, Sendable {
    func read() -> AudioFeatures
}

nonisolated func audioClock() -> Double {
    ProcessInfo.processInfo.systemUptime
}
