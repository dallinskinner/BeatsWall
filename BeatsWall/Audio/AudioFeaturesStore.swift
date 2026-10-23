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
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func publish(_ features: AudioFeatures, beat: Bool, hasSignal: Bool) {
        let now = audioClock()
        state.withLock { state in
            state.features = features
            state.updatedAt = now
            if beat { state.lastBeatAt = now }
            if hasSignal { state.lastSignalAt = now }
        }
    }

    func read() -> AudioFeatures {
        let now = audioClock()
        let state = state.withLock { $0 }
        var features = state.features

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
        audioClock() - state.withLock { $0.lastSignalAt }
    }
}
