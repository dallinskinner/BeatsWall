//
//  CampfireWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct CampfireWallpaper: View {
    let context: WallpaperContext

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DesertTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.62
        let ground = size.height * 0.8
        let fire = CGPoint(x: size.width * 0.5, y: ground + unit * 0.02)
        let heat = 0.45 + 0.55 * Double(audio.bass)

        DesertTheme.sky(in: &graphics, size: size, horizon: horizon)
        DesertTheme.drawStars(in: &graphics, size: size, maxY: horizon * 0.9, count: context.isPreview ? 120 : 260, time: frame.time, twinkle: Double(audio.treble))

        // Distant dunes, then the campsite ground.
        for (index, (base, amplitude, color)) in [(horizon, 0.04, DesertTheme.sand.opacity(0.7)), (horizon + unit * 0.06, 0.05, DesertTheme.duneShadow)].enumerated() {
            var dune = Path()
            dune.move(to: CGPoint(x: 0, y: size.height))
            var x: CGFloat = 0
            while x <= size.width + 6 {
                let s = Double(x / unit)
                dune.addLine(to: CGPoint(x: x, y: base - unit * CGFloat(amplitude * (1 + sin(s * 1.6 + Double(index) * 2) * 0.8 + sin(s * 3.7) * 0.2))))
                x += 6
            }
            dune.addLine(to: CGPoint(x: size.width + 6, y: size.height))
            dune.closeSubpath()
            graphics.fill(dune, with: .color(color))
        }
        graphics.fill(Path(CGRect(x: 0, y: ground - unit * 0.03, width: size.width, height: size.height)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x24182C), DesertTheme.silhouette]),
            startPoint: CGPoint(x: 0, y: ground), endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Firelight washing over the ground and the camp.
        var light = graphics
        light.blendMode = .plusLighter
        var spill = light
        spill.translateBy(x: fire.x, y: fire.y)
        spill.scaleBy(x: 1, y: 0.35)
        DesertTheme.glow(in: spill, at: .zero, radius: unit * CGFloat(0.5 + 0.2 * heat), color: DesertTheme.fire, opacity: 0.35 * heat)

        // Tent on the left, lit on its fire-facing side.
        var tent = Path()
        let tentBase = CGPoint(x: size.width * 0.27, y: ground)
        tent.addLines([tentBase + CGPoint(x: -unit * 0.16, y: 0), tentBase + CGPoint(x: 0, y: -unit * 0.2), tentBase + CGPoint(x: unit * 0.14, y: 0)])
        tent.closeSubpath()
        graphics.fill(tent, with: .linearGradient(
            Gradient(colors: [DesertTheme.silhouette, Color(hex: 0x7A3E2A).mix(with: DesertTheme.silhouette, by: 1 - heat * 0.8)]),
            startPoint: tentBase + CGPoint(x: -unit * 0.16, y: 0), endPoint: tentBase + CGPoint(x: unit * 0.14, y: 0)
        ))
        var flap = Path()
        flap.addLines([tentBase + CGPoint(x: -unit * 0.01, y: -unit * 0.18), tentBase + CGPoint(x: unit * 0.05, y: 0), tentBase + CGPoint(x: -unit * 0.04, y: 0)])
        flap.closeSubpath()
        graphics.fill(flap, with: .color(DesertTheme.silhouette))

        // Cacti on the right.
        graphics.fill(DesertTheme.cactus(base: CGPoint(x: size.width * 0.78, y: ground + unit * 0.01), height: unit * 0.3, seed: 1), with: .color(DesertTheme.silhouette))
        graphics.fill(DesertTheme.cactus(base: CGPoint(x: size.width * 0.9, y: ground - unit * 0.01), height: unit * 0.18, seed: 4), with: .color(DesertTheme.silhouette))
        // Rocks circling the fire.
        var stones = Path()
        for index in 0..<7 {
            let angle = Double(index) / 7 * .pi + .pi * 0.02
            let point = fire + CGPoint(x: cos(angle) * unit * 0.09, y: sin(angle) * unit * 0.018 + unit * 0.005)
            stones.addEllipse(in: CGRect(x: point.x - unit * 0.018, y: point.y - unit * 0.012, width: unit * 0.036, height: unit * 0.022))
        }
        graphics.fill(stones, with: .color(Color(hex: 0x3A2A30)))
        // Logs.
        var logs = Path()
        logs.addLines([fire + CGPoint(x: -unit * 0.07, y: unit * 0.005), fire + CGPoint(x: unit * 0.06, y: -unit * 0.02)])
        logs.move(to: fire + CGPoint(x: unit * 0.07, y: unit * 0.005))
        logs.addLine(to: fire + CGPoint(x: -unit * 0.06, y: -unit * 0.02))
        graphics.stroke(logs, with: .color(Color(hex: 0x3A2218)), style: StrokeStyle(lineWidth: unit * 0.018, lineCap: .round))

        // Glow and flames.
        DesertTheme.glow(in: light, at: fire + CGPoint(x: 0, y: -unit * 0.08), radius: unit * CGFloat(0.25 + 0.12 * heat), color: DesertTheme.fire, opacity: 0.3 * heat)
        let tongues: [(dx: CGFloat, height: CGFloat, width: CGFloat, color: Color)] = [
            (-0.035, 0.13, 0.045, DesertTheme.ember), (0.035, 0.14, 0.045, DesertTheme.ember), (0, 0.2, 0.06, DesertTheme.fire),
            (-0.018, 0.12, 0.035, DesertTheme.fire), (0.02, 0.13, 0.035, DesertTheme.flame), (0, 0.09, 0.03, Color(hex: 0xFFF3C4)),
        ]
        for (index, tongue) in tongues.enumerated() {
            let flicker = 0.85 + 0.15 * sin(frame.time * (9 + Double(index) * 2.3) + Double(index)) * sin(frame.time * 5.1 + Double(index))
            let height = unit * tongue.height * CGFloat((0.65 + 0.5 * heat) * flicker)
            let base = fire + CGPoint(x: unit * tongue.dx, y: -unit * 0.01)
            let sway = unit * 0.02 * CGFloat(sin(frame.time * 3 + Double(index) * 1.7))
            let tip = base + CGPoint(x: sway, y: -height)
            let half = unit * tongue.width / 2
            var flame = Path()
            flame.move(to: base + CGPoint(x: -half, y: 0))
            flame.addQuadCurve(to: tip, control: base + CGPoint(x: -half * 1.1 + sway * 0.3, y: -height * 0.55))
            flame.addQuadCurve(to: base + CGPoint(x: half, y: 0), control: base + CGPoint(x: half * 1.1 + sway * 0.3, y: -height * 0.55))
            flame.addQuadCurve(to: base + CGPoint(x: -half, y: 0), control: base + CGPoint(x: 0, y: half * 0.6))
            light.fill(flame, with: .color(tongue.color.opacity(0.85)))
        }

        // Sparks rising, more of them with the hi-hats.
        var sparks = Path()
        for index in 0..<(context.isPreview ? 30 : 70) {
            let speed = 0.35 + 0.4 * hash01(index, 11)
            let cycle = frame.time * speed + hash01(index, 12)
            let progress = cycle - cycle.rounded(.down)
            guard hash01(index, Int(cycle.rounded(.down))) < 0.25 + 0.75 * Double(audio.treble) else { continue }
            let point = fire + CGPoint(
                x: unit * 0.04 * CGFloat(sin(progress * 6 + Double(index))) * CGFloat(progress) + unit * 0.02 * CGFloat(hash01(index, 13) - 0.5),
                y: -unit * 0.08 - unit * 0.45 * CGFloat(progress)
            )
            sparks.addPath(DesertTheme.disc(point, unit * 0.0025 * CGFloat(1 - progress * 0.6)))
        }
        light.fill(sparks, with: .color(DesertTheme.flame.opacity(0.9)))
    }
}
