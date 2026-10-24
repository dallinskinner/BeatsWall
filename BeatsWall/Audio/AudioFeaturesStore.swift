//
//  AudioFeaturesStore.swift
//  BeatsWall
//

import Foundation
import os

/// Holds the latest analyzed features. The analyzer writes from the audio queue and
/// wallpapers read once per frame. It intentionally isn't observable, so 100 updates a
/// second never invalidate SwiftUI views.
nonisolated final class AudioFeaturesStore: AudioFeatureSource {
    private struct State: Sendable {
        var features = AudioFeatures()
        var updatedAt = -Double.infinity
        var lastBeatAt = -Double.infinity
        var lastSignalAt = -Double.infinity
        var gain: Float = 1
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let clock: @Sendable () -> Double

    /// `clock` is injectable so offline rendering can run on video time.
    init(clock: @escaping @Sendable () -> Double = audioClock) {
        self.clock = clock
    }

    func publish(_ features: AudioFeatures, beat: Bool, hasSignal: Bool) {
        let now = clock()
        state.withLock { state in
            state.features = features
            state.updatedAt = now
            if beat { state.lastBeatAt = now }
            if hasSignal { state.lastSignalAt = now }
        }
    }

    /// Scales levels before wallpapers see them, so quiet setups can still drive big visuals.
    var gain: Float {
        get { state.withLock { $0.gain } }
        set { state.withLock { $0.gain = newValue } }
    }

    func read() -> AudioFeatures {
        let now = clock()
        let state = state.withLock { $0 }
        var features = state.features

        if state.gain != 1 {
            let gain = state.gain
            features.level = min(1, features.level * gain)
            features.bass = min(1, features.bass * gain)
            features.mid = min(1, features.mid * gain)
            features.treble = min(1, features.treble * gain)
            features.spectrum = features.spectrum.map { min(1, $0 * gain) }
        }

        // If buffers stop arriving (device change, capture stopped), fade out instead of freezing.
        let staleness = now - state.updatedAt - 0.25
        if staleness > 0 {
            let fade = Float(exp(-staleness * 3))
            features.level *= fade
            features.bass *= fade
            features.mid *= fade
            features.treble *= fade
            features.spectrum = features.spectrum.map { $0 * fade }
        }
        features.secondsSinceBeat = now - state.lastBeatAt
        features.beatPulse = Float(exp(-features.secondsSinceBeat * AudioFeatures.beatDecay))
        return features
    }

    var secondsSinceSignal: Double {
        clock() - state.withLock { $0.lastSignalAt }
    }
}
