//
//  SpaceTheme.swift
//  BeatsWall
//

import SwiftUI

enum SpaceTheme {
    static let void = Color(hex: 0x05060F)
    static let deep = Color(hex: 0x1A1035)
    static let violet = Color(hex: 0x5B2A86)
    static let pink = Color(hex: 0xE0479E)
    static let teal = Color(hex: 0x2EC4B6)
    static let ice = Color(hex: 0xBFE6FF)

    /// A fixed starfield. Stars twinkle at their own rates, more with the treble, and a few
    /// flare into four-point sparkles on each beat.
    static func drawStars(in graphics: inout GraphicsContext, size: CGSize, count: Int, audio: AudioFeatures, time: Double, drift: CGFloat = 0) {
        let unit = min(size.width, size.height)
        var dim = Path()
        var bright = Path()
        var flares = Path()
        for index in 0..<count {
            let depth = 0.3 + 0.7 * hash01(index, 203)
            let rawX = CGFloat(hash01(index, 201)) * size.width - drift * CGFloat(depth)
            let x = rawX - (rawX / size.width).rounded(.down) * size.width
            let y = CGFloat(hash01(index, 202)) * size.height
            let shimmer = 0.5 + 0.5 * sin(time * (0.7 + 2.5 * hash01(index, 204)) + Double(index))
            let r = unit * 0.0016 * CGFloat(depth * (0.6 + shimmer * (0.4 + Double(audio.treble))))
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            if shimmer > 0.6 { bright.addEllipse(in: rect) } else { dim.addEllipse(in: rect) }
            if hash01(index, audio.beatCount) > 0.96 {
                let flare = unit * 0.012 * CGFloat(audio.beatPulse) * CGFloat(depth)
                flares.move(to: CGPoint(x: x - flare, y: y))
                flares.addLine(to: CGPoint(x: x + flare, y: y))
                flares.move(to: CGPoint(x: x, y: y - flare))
                flares.addLine(to: CGPoint(x: x, y: y + flare))
            }
        }
        graphics.fill(dim, with: .color(.white.opacity(0.5)))
        graphics.fill(bright, with: .color(.white.opacity(0.95)))
        graphics.stroke(flares, with: .color(ice.opacity(0.9)), style: StrokeStyle(lineWidth: max(1, unit * 0.0012), lineCap: .round))
    }
}
