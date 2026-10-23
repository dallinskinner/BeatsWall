//
//  WallpaperKit.swift
//  BeatsWall
//
//  Small helpers shared by every collection.
//

import SwiftUI

extension Color {
    /// `Color(hex: 0xD97757)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Deterministic pseudo-random value in 0..<1 for a pair of integers, e.g. (item, beatCount).
nonisolated func hash01(_ a: Int, _ b: Int = 0) -> Double {
    var x = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663)
    x ^= x >> 13
    x &*= 0x5bd1_e995
    x ^= x >> 15
    return Double(x % 10_000) / 10_000
}

/// Integrates a phase at a variable speed, so changing speed never makes motion jump.
/// Also reports the frame's delta time for simulations.
final class PhaseClock {
    private(set) var phase: Double = 0
    private(set) var deltaTime: Double = 0
    private var lastTime: Double?

    @discardableResult
    func advance(to time: Double, speed: Double = 1) -> Double {
        deltaTime = lastTime.map { min(max(time - $0, 0), 0.1) } ?? 0
        lastTime = time
        phase += deltaTime * speed
        return phase
    }
}

/// Reports `true` exactly once for each new beat.
struct BeatEdge {
    private var lastBeatCount: Int?

    mutating func isNewBeat(_ audio: AudioFeatures) -> Bool {
        defer { lastBeatCount = audio.beatCount }
        return lastBeatCount.map { $0 != audio.beatCount } ?? false
    }
}

extension Path {
    /// Adds pixel art described as rows of text, where `#` is a filled pixel.
    mutating func addPixelSprite(_ rows: [String], origin: CGPoint, pixelWidth: CGFloat, pixelHeight: CGFloat? = nil) {
        let height = pixelHeight ?? pixelWidth
        for (row, line) in rows.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                addRect(CGRect(
                    x: origin.x + CGFloat(column) * pixelWidth,
                    y: origin.y + CGFloat(row) * height,
                    width: pixelWidth + 0.5,
                    height: height + 0.5
                ))
            }
        }
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }

    var length: CGFloat { hypot(x, y) }
}

extension Double {
    /// Linear interpolation from `a` to `b` by `self` (0...1).
    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * self }
}

/// Hermite step: 0 below `edge0`, 1 above `edge1`, smooth in between.
nonisolated func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
}
