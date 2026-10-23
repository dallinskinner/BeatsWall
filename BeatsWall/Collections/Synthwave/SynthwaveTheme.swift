//
//  SynthwaveTheme.swift
//  BeatsWall
//

import SwiftUI

enum SynthwaveTheme {
    static let magenta = Color(hex: 0xFF2E97)
    static let purple = Color(hex: 0x7B2FF7)
    static let cyan = Color(hex: 0x00E5FF)
    static let yellow = Color(hex: 0xFFD23F)
    static let orange = Color(hex: 0xFF8C42)
    static let night = Color(hex: 0x12002B)
    static let deepNight = Color(hex: 0x0B0221)
    static let dusk = Color(hex: 0x2A0A4A)

    /// 0...1 from the detected tempo (0.5 until one is known), for scroll speeds.
    static func tempo(_ audio: AudioFeatures) -> Double {
        audio.bpm > 0 ? min(max((Double(audio.bpm) - 70) / 90, 0), 1) : 0.5
    }

    /// The classic striped sunset sun. Stripes scroll downward and thicken with the bass.
    static func drawSun(in graphics: inout GraphicsContext, center: CGPoint, radius: CGFloat, bass: Double, scroll: Double) {
        let glow = radius * 1.7
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(Gradient(colors: [magenta.opacity(0.45), magenta.opacity(0)]), center: center, startRadius: radius * 0.8, endRadius: glow)
        )
        graphics.drawLayer { layer in
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            layer.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [yellow, orange, magenta]),
                startPoint: CGPoint(x: center.x, y: rect.minY), endPoint: CGPoint(x: center.x, y: rect.maxY)
            ))
            layer.blendMode = .destinationOut
            var stripes = Path()
            let count = 7
            let offset = scroll - scroll.rounded(.down)
            for index in -1..<count {
                let t = (Double(index) + offset) / Double(count)
                guard t >= 0 else { continue }
                let y = center.y - radius * 0.05 + radius * 1.05 * CGFloat(t)
                let height = radius * CGFloat(0.025 + 0.1 * t) * CGFloat(0.75 + 0.8 * bass)
                stripes.addRect(CGRect(x: rect.minX, y: y, width: rect.width, height: height))
            }
            layer.fill(stripes, with: .color(.black))
        }
    }

    static func drawStars(in graphics: inout GraphicsContext, size: CGSize, maxY: CGFloat, count: Int, twinkle: Double, time: Double) {
        let unit = min(size.width, size.height)
        var stars = Path()
        for index in 0..<count {
            let x = CGFloat(hash01(index, 101)) * size.width
            let y = CGFloat(hash01(index, 102)) * maxY
            let shimmer = 0.5 + 0.5 * sin(time * (1 + 3 * hash01(index, 103)) + Double(index))
            let r = unit * 0.0022 * CGFloat(0.5 + hash01(index, 104) + twinkle * shimmer)
            stars.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.85)))
    }

    /// Strokes a path as a neon tube: a soft wide glow under a bright core.
    static func neon(_ path: Path, in graphics: GraphicsContext, color: Color, width: CGFloat, brightness: Double = 1) {
        graphics.stroke(path, with: .color(color.opacity(0.18 * brightness)), style: StrokeStyle(lineWidth: width * 6, lineCap: .round, lineJoin: .round))
        graphics.stroke(path, with: .color(color.opacity(0.35 * brightness)), style: StrokeStyle(lineWidth: width * 2.5, lineCap: .round, lineJoin: .round))
        graphics.stroke(path, with: .color(color.mix(with: .white, by: 0.35).opacity(brightness)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
