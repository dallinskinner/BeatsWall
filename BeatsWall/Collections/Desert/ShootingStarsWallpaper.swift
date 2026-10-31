//
//  ShootingStarsWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct ShootingStarsWallpaper: View {
    let context: WallpaperContext
    @State private var meteors = MeteorShower()

    /// Invented constellations, in fractions of the sky.
    private static let constellations: [[CGPoint]] = [
        [CGPoint(x: 0.08, y: 0.18), CGPoint(x: 0.13, y: 0.1), CGPoint(x: 0.2, y: 0.14), CGPoint(x: 0.24, y: 0.07), CGPoint(x: 0.3, y: 0.12), CGPoint(x: 0.27, y: 0.22)],
        [CGPoint(x: 0.42, y: 0.3), CGPoint(x: 0.47, y: 0.22), CGPoint(x: 0.53, y: 0.26), CGPoint(x: 0.5, y: 0.36), CGPoint(x: 0.42, y: 0.3)],
        [CGPoint(x: 0.66, y: 0.08), CGPoint(x: 0.71, y: 0.15), CGPoint(x: 0.78, y: 0.12), CGPoint(x: 0.84, y: 0.2), CGPoint(x: 0.9, y: 0.16)],
        [CGPoint(x: 0.72, y: 0.36), CGPoint(x: 0.78, y: 0.31), CGPoint(x: 0.83, y: 0.38), CGPoint(x: 0.79, y: 0.45), CGPoint(x: 0.86, y: 0.48)],
    ]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                meteors.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DesertTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.78
        DesertTheme.sky(in: &graphics, size: size, horizon: horizon)

        // The Milky Way: a soft diagonal band dense with tiny stars.
        var band = graphics
        band.translateBy(x: size.width / 2, y: size.height * 0.38)
        band.rotate(by: .radians(-0.42))
        band.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.06))
            layer.fill(Path(ellipseIn: CGRect(x: -size.width * 0.75, y: -unit * 0.09, width: size.width * 1.5, height: unit * 0.18)), with: .color(Color(hex: 0x8C7BC9).opacity(0.28)))
            layer.fill(Path(ellipseIn: CGRect(x: -size.width * 0.4, y: -unit * 0.04, width: size.width * 0.8, height: unit * 0.08)), with: .color(Color(hex: 0xE8D8F0).opacity(0.18)))
        }
        var dust = Path()
        for index in 0..<(context.isReduced ? 200 : 600) {
            let along = CGFloat(hash01(index, 1) - 0.5) * size.width * 1.4
            let across = CGFloat((hash01(index, 2) + hash01(index, 3) - 1)) * unit * 0.09
            dust.addEllipse(in: CGRect(x: along, y: across, width: unit * 0.0022, height: unit * 0.0022))
        }
        band.fill(dust, with: .color(.white.opacity(0.55)))
        DesertTheme.drawStars(in: &graphics, size: size, maxY: horizon, count: context.isReduced ? 120 : 240, time: frame.time, twinkle: Double(audio.treble))

        // Constellations draw themselves as their part of the spectrum swells.
        var lines = Path()
        var anchors = Path()
        for (index, stars) in Self.constellations.enumerated() {
            let energy = MinimalTheme.band(index, of: Self.constellations.count, in: audio.spectrum)
            let points = stars.map { CGPoint(x: $0.x * size.width, y: $0.y * horizon) }
            let segments = points.count - 1
            let reveal = CGFloat(min(1, energy * 1.4)) * CGFloat(segments)
            for segment in 0..<segments where CGFloat(segment) < reveal {
                let amount = min(1, reveal - CGFloat(segment))
                lines.move(to: points[segment])
                lines.addLine(to: points[segment] + (points[segment + 1] - points[segment]) * amount)
            }
            for point in points { anchors.addPath(DesertTheme.disc(point, unit * 0.004)) }
        }
        graphics.stroke(lines, with: .color(Color(hex: 0xBFD7FF).opacity(0.45)), style: StrokeStyle(lineWidth: max(1, unit * 0.0015), lineCap: .round))
        var light = graphics
        light.blendMode = .plusLighter
        light.fill(anchors, with: .color(.white))

        // Shooting stars.
        for meteor in meteors.active {
            let age = (frame.time - meteor.born) / meteor.life
            let start = CGPoint(x: meteor.x * size.width, y: meteor.y * horizon)
            let direction = CGPoint(x: cos(meteor.angle), y: sin(meteor.angle))
            let head = start + direction * (unit * 0.6 * CGFloat(age))
            let tail = head - direction * (unit * 0.18 * CGFloat(1 - age * 0.5))
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            let fade = sin(.pi * age)
            light.stroke(streak, with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(fade)]), startPoint: tail, endPoint: head), style: StrokeStyle(lineWidth: max(1, unit * 0.003), lineCap: .round))
            DesertTheme.glow(in: light, at: head, radius: unit * 0.012, color: .white, opacity: 0.8 * fade)
        }

        // Mesas and a lone cactus on the horizon.
        var land = Path()
        land.move(to: CGPoint(x: 0, y: size.height))
        land.addLine(to: CGPoint(x: 0, y: horizon))
        let mesas: [(CGFloat, CGFloat, CGFloat)] = [(0.1, 0.22, 0.09), (0.55, 0.16, 0.06), (0.8, 0.12, 0.12)]
        var x: CGFloat = 0
        for (start, width, height) in mesas {
            land.addLine(to: CGPoint(x: size.width * start, y: horizon))
            land.addLine(to: CGPoint(x: size.width * start + unit * 0.03, y: horizon - unit * height))
            land.addLine(to: CGPoint(x: size.width * (start + width) - unit * 0.03, y: horizon - unit * height))
            land.addLine(to: CGPoint(x: size.width * (start + width), y: horizon))
            x = size.width * (start + width)
        }
        land.addLine(to: CGPoint(x: max(x, size.width), y: horizon))
        land.addLine(to: CGPoint(x: size.width, y: size.height))
        land.closeSubpath()
        graphics.fill(land, with: .color(DesertTheme.silhouette))
        graphics.fill(DesertTheme.cactus(base: CGPoint(x: size.width * 0.42, y: horizon + unit * 0.01), height: unit * 0.16, seed: 7), with: .color(DesertTheme.silhouette))
    }
}

/// Shooting stars on the beat, plus one every few seconds when it's quiet.
private final class MeteorShower {
    struct Meteor {
        var x: CGFloat
        var y: CGFloat
        var angle: Double
        var born: Double
        var life: Double
    }

    private(set) var active: [Meteor] = []
    private var beatEdge = BeatEdge()
    private var lastSpawn = 0.0

    func step(frame: AudioFrame) {
        let audio = frame.audio
        if beatEdge.isNewBeat(audio), hash01(audio.beatCount, 3) < 0.25 + 0.5 * Double(audio.bass) {
            spawn(at: frame.time)
        } else if frame.time - lastSpawn > 3.5 {
            spawn(at: frame.time)
        }
        active.removeAll { frame.time - $0.born > $0.life }
    }

    private func spawn(at time: Double) {
        lastSpawn = time
        active.append(Meteor(
            x: .random(in: 0.1...0.8), y: .random(in: 0.02...0.35),
            angle: .random(in: 0.35...0.7), born: time, life: .random(in: 0.5...0.9)
        ))
    }
}
