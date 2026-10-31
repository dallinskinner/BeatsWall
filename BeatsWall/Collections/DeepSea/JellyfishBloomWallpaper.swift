//
//  JellyfishBloomWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct JellyfishBloomWallpaper: View {
    let context: WallpaperContext
    @State private var bloom: JellyBloom

    init(context: WallpaperContext) {
        self.context = context
        _bloom = State(initialValue: JellyBloom(count: context.isReduced ? 5 : 8))
    }

    private static let colors = [DeepSeaTheme.cyan, DeepSeaTheme.pink, DeepSeaTheme.violet]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                bloom.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DeepSeaTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let unit = min(size.width, size.height)
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [DeepSeaTheme.midwater, DeepSeaTheme.deep, DeepSeaTheme.abyss]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        DeepSeaTheme.drawGodRays(in: &graphics, size: size, time: frame.time, intensity: 0.7)
        DeepSeaTheme.drawMarineSnow(in: &graphics, size: size, time: frame.time, count: context.isReduced ? 60 : 160)

        var light = graphics
        light.blendMode = .plusLighter
        // Far jellies first so nearer ones overlap them.
        for jelly in bloom.jellies.sorted(by: { $0.depth < $1.depth }) {
            let center = CGPoint(x: CGFloat(jelly.x) * size.width, y: CGFloat(jelly.y) * size.height)
            let width = unit * CGFloat(0.06 + 0.1 * jelly.depth)
            let contract = CGFloat(jelly.contract)
            let bellWidth = width * (1 - 0.22 * contract)
            let bellHeight = width * 0.75 * (1 + 0.18 * contract)
            let color = Self.colors[jelly.colorIndex]
            let opacity = 0.35 + 0.45 * jelly.depth

            // Tentacles trail behind, waving.
            var tentacles = Path()
            for strand in 0..<7 {
                let startX = center.x - bellWidth * 0.42 + bellWidth * 0.84 * CGFloat(strand) / 6
                tentacles.move(to: CGPoint(x: startX, y: center.y))
                for step in 1...16 {
                    let t = Double(step) / 16
                    let wave = sin(frame.time * 1.6 - t * 5 + Double(strand) + jelly.seed * 10) * Double(width) * 0.12 * t
                    tentacles.addLine(to: CGPoint(x: startX + CGFloat(wave), y: center.y + width * 2.2 * CGFloat(t)))
                }
            }
            light.stroke(tentacles, with: .color(color.opacity(0.25 * opacity)), lineWidth: max(1, width * 0.02))
            var arms = Path()
            for side: CGFloat in [-1, 1] {
                arms.move(to: CGPoint(x: center.x + side * bellWidth * 0.1, y: center.y))
                for step in 1...12 {
                    let t = Double(step) / 12
                    let wave = sin(frame.time * 1.2 - t * 4 + Double(side) + jelly.seed * 5) * Double(width) * 0.1
                    arms.addLine(to: CGPoint(x: center.x + side * bellWidth * 0.1 + CGFloat(wave), y: center.y + width * 1.2 * CGFloat(t)))
                }
            }
            light.stroke(arms, with: .color(color.opacity(0.4 * opacity)), style: StrokeStyle(lineWidth: width * 0.06, lineCap: .round))

            // Bell: a dome with a scalloped rim.
            var bell = Path()
            bell.move(to: CGPoint(x: center.x - bellWidth / 2, y: center.y))
            bell.addCurve(to: CGPoint(x: center.x + bellWidth / 2, y: center.y), control1: CGPoint(x: center.x - bellWidth / 2, y: center.y - bellHeight * 1.3), control2: CGPoint(x: center.x + bellWidth / 2, y: center.y - bellHeight * 1.3))
            let scallops = 8
            for index in stride(from: scallops, to: 0, by: -1) {
                let x0 = center.x - bellWidth / 2 + bellWidth * CGFloat(index - 1) / CGFloat(scallops)
                let x1 = center.x - bellWidth / 2 + bellWidth * CGFloat(index) / CGFloat(scallops)
                bell.addQuadCurve(to: CGPoint(x: x0, y: center.y), control: CGPoint(x: (x0 + x1) / 2, y: center.y + width * 0.06))
            }
            bell.closeSubpath()
            DeepSeaTheme.glow(in: light, at: CGPoint(x: center.x, y: center.y - bellHeight * 0.4), radius: width * (1.2 + 0.6 * contract), color: color, opacity: (0.2 + 0.35 * Double(contract)) * opacity)
            light.fill(bell, with: .radialGradient(
                Gradient(colors: [color.opacity(0.5 * opacity), color.opacity(0.12 * opacity)]),
                center: CGPoint(x: center.x, y: center.y - bellHeight * 0.5), startRadius: 0, endRadius: bellWidth * 0.6
            ))
            light.stroke(bell, with: .color(color.mix(with: .white, by: 0.4).opacity(0.7 * opacity)), lineWidth: max(1, width * 0.025))
        }
    }
}

/// Jellies drift slowly down and push upward on the beat.
private final class JellyBloom {
    struct Jelly {
        var x: Double
        var y: Double
        var vy: Double = 0
        var contract: Double = 0
        var depth: Double
        var seed: Double
        var colorIndex: Int
    }

    private(set) var jellies: [Jelly]
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()

    init(count: Int) {
        jellies = (0..<count).map { index in
            Jelly(x: .random(in: 0.08...0.92), y: .random(in: 0.2...1.0), depth: Double(index) / Double(max(count - 1, 1)), seed: .random(in: 0...1), colorIndex: index % 3)
        }
    }

    func step(frame: AudioFrame) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        let dt = clock.deltaTime
        let beat = beatEdge.isNewBeat(audio)
        for index in jellies.indices {
            var jelly = jellies[index]
            // Each jelly swims on its own subset of beats.
            if beat, hash01(index, audio.beatCount) > 0.35 {
                jelly.contract = 1
                jelly.vy -= 0.05 + 0.08 * Double(audio.bass)
            }
            jelly.contract *= exp(-dt * 4)
            jelly.vy += (0.008 - jelly.vy) * min(1, dt * 1.5)
            jelly.y += jelly.vy * dt
            jelly.x += sin(frame.time * 0.2 + jelly.seed * 20) * 0.004 * dt
            if jelly.y < -0.25 {
                jelly.y = 1.15
                jelly.x = .random(in: 0.08...0.92)
            }
            if jelly.y > 1.3 { jelly.y = -0.2 }
            jellies[index] = jelly
        }
    }
}
