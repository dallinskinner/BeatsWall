//
//  BeatGrid.swift
//  BeatsWall
//

import Foundation

/// A steady beat grid for cutting video on the music.
nonisolated struct BeatGrid: Sendable {
    let beatLength: Double
    /// Every beat, in seconds from the start of the video.
    let beats: [Double]
    /// Every bar's downbeat (every fourth beat).
    let bars: [Double]

    /// Detection occasionally misses a beat, so this is a steady grid at the median tempo of
    /// `detectedBeats`, anchored on the first one (120 BPM if detection came up short).
    init(detectedBeats: [Double], length: Double) {
        let intervals = zip(detectedBeats.dropFirst(), detectedBeats).map { $0 - $1 }.filter { $0 > 0.25 && $0 < 1.0 }.sorted()
        beatLength = intervals.count > 8 ? intervals[intervals.count / 2] : 0.5
        let anchor = detectedBeats.first { $0 >= -0.01 } ?? 0
        let beats = stride(from: anchor, to: length + 4, by: beatLength).map { $0 }
        self.beats = beats
        bars = stride(from: 0, to: beats.count, by: 4).map { beats[$0] }
    }

    /// Index of the first bar at or after `time`.
    func bar(atOrAfter time: Double) -> Int {
        bars.firstIndex { $0 >= time - 0.05 } ?? bars.count - 1
    }
}
