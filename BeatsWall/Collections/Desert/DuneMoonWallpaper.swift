//
//  DuneMoonWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct DuneMoonWallpaper: View {
    let context: WallpaperContext
    @State private var wind = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DesertTheme.grain())
    }

    private func ridge(_ x: CGFloat, layer: Int, size: CGSize, unit: CGFloat) -> CGFloat {
        let s = Double(x / unit)
        let base = size.height * CGFloat(0.6 + 0.12 * Double(layer))
        let shape = sin(s * (1.1 + 0.3 * Double(layer)) + Double(layer) * 2.1) + 0.35 * sin(s * 2.9 + Double(layer))
        return base - unit * CGFloat(0.06 + 0.02 * Double(layer)) * CGFloat(shape)
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let gust = wind.advance(to: frame.time, speed: 0.3 + 1.2 * Double(audio.mid))

        DesertTheme.sky(in: &graphics, size: size, horizon: size.height * 0.62)
        DesertTheme.drawStars(in: &graphics, size: size, maxY: size.height * 0.5, count: context.isReduced ? 80 : 160, time: frame.time, twinkle: Double(audio.treble))

        // A giant moon sitting low on the horizon.
        let moon = CGPoint(x: size.width * 0.62, y: size.height * 0.46)
        let moonRadius = unit * 0.28
        DesertTheme.glow(in: graphics, at: moon, radius: moonRadius * 2.2, color: DesertTheme.moon, opacity: 0.18 + 0.08 * Double(audio.level))
        graphics.fill(DesertTheme.disc(moon, moonRadius), with: .radialGradient(
            Gradient(colors: [DesertTheme.moon, Color(hex: 0xE8C9A0)]),
            center: moon + CGPoint(x: -moonRadius * 0.3, y: -moonRadius * 0.3), startRadius: 0, endRadius: moonRadius * 1.4
        ))
        var maria = Path()
        for (dx, dy, r) in [(-0.3, -0.2, 0.22), (0.2, 0.15, 0.3), (0.35, -0.35, 0.12), (-0.15, 0.45, 0.14)] {
            maria.addPath(DesertTheme.disc(moon + CGPoint(x: dx * moonRadius, y: dy * moonRadius), moonRadius * CGFloat(r)))
        }
        graphics.fill(maria, with: .color(Color(hex: 0xCDB48E).opacity(0.5)))

        // Dunes: moonlit crests, shadowed slopes.
        for layer in 0..<3 {
            var dune = Path()
            var crest = Path()
            dune.move(to: CGPoint(x: 0, y: size.height))
            var x: CGFloat = 0
            while x <= size.width + 6 {
                let y = ridge(x, layer: layer, size: size, unit: unit)
                dune.addLine(to: CGPoint(x: x, y: y))
                if x == 0 { crest.move(to: CGPoint(x: x, y: y)) } else { crest.addLine(to: CGPoint(x: x, y: y)) }
                x += 6
            }
            dune.addLine(to: CGPoint(x: size.width + 6, y: size.height))
            dune.closeSubpath()
            let depth = Double(layer) / 2
            graphics.fill(dune, with: .linearGradient(
                Gradient(colors: [DesertTheme.sandLit.mix(with: DesertTheme.sand, by: depth), DesertTheme.duneShadow]),
                startPoint: CGPoint(x: 0, y: size.height * CGFloat(0.55 + 0.12 * Double(layer))), endPoint: CGPoint(x: 0, y: size.height)
            ))
            graphics.stroke(crest, with: .color(DesertTheme.moon.opacity(0.35 - 0.1 * depth)), lineWidth: max(1, unit * 0.002))

            // Sand streaming off the crest in the wind.
            var sand = Path()
            for grain in 0..<(context.isReduced ? 30 : 80) {
                let start = CGFloat(hash01(grain, layer + 10)) * size.width
                let drift = (gust * 0.2 + hash01(grain, layer + 20)).truncatingRemainder(dividingBy: 1)
                let point = CGPoint(x: start + unit * 0.12 * CGFloat(drift), y: ridge(start, layer: layer, size: size, unit: unit) - unit * 0.03 * CGFloat(sin(.pi * drift)))
                if hash01(grain, Int(gust * 2)) < 0.2 + 0.7 * Double(audio.mid) {
                    sand.addPath(DesertTheme.disc(point, unit * 0.0015))
                }
            }
            graphics.fill(sand, with: .color(DesertTheme.moon.opacity(0.45)))

            if layer == 0 {
                drawCaravan(in: &graphics, size: size, unit: unit, frame: frame)
            }
        }
    }

    /// Camels walking along the far ridge, stepping in tempo.
    private func drawCaravan(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame) {
        let beat = frame.audio.beatProgress(at: frame.time)
        let travel = CGFloat((frame.time * 0.008).truncatingRemainder(dividingBy: 1)) * (size.width + unit * 0.8) - unit * 0.4
        let color = DesertTheme.silhouette
        for camel in 0..<4 {
            let x = travel - CGFloat(camel) * unit * 0.1
            let groundY = ridge(x, layer: 0, size: size, unit: unit)
            let s = unit * 0.045
            var g = graphics
            g.translateBy(x: x, y: groundY)
            g.scaleBy(x: s, y: s)
            // Long body with a single tall hump, rising into a long curved neck and small head.
            var body = Path()
            body.move(to: CGPoint(x: -1.1, y: -1.55))
            body.addQuadCurve(to: CGPoint(x: -0.55, y: -2.0), control: CGPoint(x: -1.05, y: -1.95))
            body.addQuadCurve(to: CGPoint(x: 0.35, y: -1.95), control: CGPoint(x: -0.1, y: -2.75))
            body.addQuadCurve(to: CGPoint(x: 0.85, y: -1.75), control: CGPoint(x: 0.65, y: -1.8))
            body.addQuadCurve(to: CGPoint(x: 1.25, y: -2.45), control: CGPoint(x: 1.05, y: -1.9))
            body.addQuadCurve(to: CGPoint(x: 1.65, y: -2.4), control: CGPoint(x: 1.45, y: -2.62))
            body.addLine(to: CGPoint(x: 1.62, y: -2.22))
            body.addQuadCurve(to: CGPoint(x: 1.35, y: -2.2), control: CGPoint(x: 1.5, y: -2.18))
            body.addQuadCurve(to: CGPoint(x: 0.95, y: -1.35), control: CGPoint(x: 1.1, y: -1.6))
            body.addQuadCurve(to: CGPoint(x: -1.1, y: -1.55), control: CGPoint(x: -0.1, y: -1.05))
            body.closeSubpath()
            // Tail.
            body.move(to: CGPoint(x: -1.05, y: -1.6))
            body.addLine(to: CGPoint(x: -1.25, y: -1.15))
            body.addLine(to: CGPoint(x: -1.15, y: -1.15))
            body.closeSubpath()
            if camel == 0 {
                // A robed rider sitting behind the hump.
                body.addRoundedRect(in: CGRect(x: -0.75, y: -2.85, width: 0.36, height: 0.95), cornerSize: CGSize(width: 0.15, height: 0.15))
                body.addEllipse(in: CGRect(x: -0.72, y: -3.15, width: 0.3, height: 0.3))
            }
            g.fill(body, with: .color(color))
            var legs = Path()
            for (index, legX) in [-0.75, -0.5, 0.45, 0.7].enumerated() {
                let phase = beat * .pi + Double(index % 2) * .pi + Double(camel) * 0.5
                let swing = CGFloat(sin(phase)) * 0.25
                legs.move(to: CGPoint(x: legX, y: -1.4))
                legs.addLine(to: CGPoint(x: legX + swing, y: 0))
            }
            g.stroke(legs, with: .color(color), style: StrokeStyle(lineWidth: 0.16, lineCap: .round))
        }
    }
}
