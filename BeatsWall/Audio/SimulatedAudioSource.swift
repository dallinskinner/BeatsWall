//
//  SimulatedAudioSource.swift
//  BeatsWall
//

import Foundation

/// A synthetic 120 BPM track used for browser thumbnails and when system audio is unavailable.
nonisolated final class SimulatedAudioSource: AudioFeatureSource {
    static let shared = SimulatedAudioSource()

    private static let beatLength = 0.5

    func read() -> AudioFeatures {
        let time = audioClock()
        let beats = time / Self.beatLength
        let secondsSinceBeat = (beats - beats.rounded(.down)) * Self.beatLength
        // Slow phrase-level swell so the demo breathes rather than looping identically.
        let swell = 0.5 + 0.5 * sin(time * 0.21)

        var features = AudioFeatures()
        features.bpm = 120
        features.beatCount = Int(beats)
        features.beatPulse = Float(exp(-secondsSinceBeat * 4.5))
        features.bass = clamp(0.25 + 0.65 * Double(features.beatPulse) * (0.6 + 0.4 * swell))
        features.mid = clamp((0.45 + 0.2 * sin(time * 1.7) + 0.15 * sin(time * 0.53)) * (0.7 + 0.3 * swell))
        features.treble = clamp(0.35 + 0.15 * sin(time * 4.3 + 1) + 0.1 * sin(time * 9.1))
        features.level = (features.bass + features.mid + features.treble) / 3

        let count = AudioFeatures.binCount
        for bin in 0..<count {
            let x = Double(bin) / Double(count - 1)
            let low = Double(features.bass) * exp(-x * 6)
            let middle = Double(features.mid) * exp(-pow((x - 0.45) * 4, 2)) * 0.8
            let high = Double(features.treble) * exp(-pow((x - 0.8) * 5, 2)) * 0.7
            let wobble = 0.12 * sin(time * (2 + Double(bin) * 0.37) + Double(bin)) * (0.5 + 0.5 * swell)
            features.spectrum[bin] = clamp(low + middle + high + wobble)
        }
        return features
    }

    private func clamp(_ value: Double) -> Float {
        Float(min(1, max(0, value)))
    }
}
