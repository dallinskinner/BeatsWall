//
//  WaterfallPoolWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct WaterfallPoolWallpaper: View {
    let context: WallpaperContext
    @State private var flow = PhaseClock()
    @State private var ripples = PoolRipples()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                ripples.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(JungleTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let phase = flow.advance(to: frame.time, speed: 1 + Double(audio.level))
        let pool = size.height * 0.68
        let fall = CGRect(x: size.width * 0.42, y: 0, width: size.width * 0.16, height: pool)

        // Dusky jungle backdrop.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x16324A), Color(hex: 0x1E4A3A), JungleTheme.deep]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Cliffs either side of the falls.
        for side: CGFloat in [-1, 1] {
            var cliff = Path()
            let inner = side < 0 ? fall.minX : fall.maxX
            let outer = side < 0 ? -unit * 0.05 : size.width + unit * 0.05
            cliff.move(to: CGPoint(x: outer, y: pool + unit * 0.02))
            cliff.addLine(to: CGPoint(x: outer, y: size.height * 0.05))
            for step in 0...10 {
                let t = CGFloat(step) / 10
                let x = outer + (inner - outer) * t
                let jag = unit * 0.02 * CGFloat(hash01(step, side < 0 ? 1 : 2))
                cliff.addLine(to: CGPoint(x: x, y: size.height * 0.05 * (1 - t) + jag))
            }
            cliff.addLine(to: CGPoint(x: inner, y: pool + unit * 0.02))
            cliff.closeSubpath()
            graphics.fill(cliff, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x2A3A36), Color(hex: 0x16211E)]),
                startPoint: CGPoint(x: outer, y: 0), endPoint: CGPoint(x: inner, y: 0)
            ))
            // Hanging vines and ferns on the cliffs.
            for index in 0..<6 {
                let base = CGPoint(x: outer + (inner - outer) * CGFloat(0.1 + 0.15 * Double(index)), y: size.height * CGFloat(0.03 + 0.05 * hash01(index, 4)))
                let frond = JungleTheme.frond(base: base, angle: .pi / 2 + Double(side) * 0.3 + sin(phase * 0.5 + Double(index)) * 0.05, length: unit * CGFloat(0.12 + 0.08 * hash01(index, 5)), droop: unit * 0.02)
                graphics.fill(frond, with: .color(index % 2 == 0 ? JungleTheme.leaf : JungleTheme.mid))
            }
        }

        // The falls: streaks rushing down.
        graphics.fill(Path(fall), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x8FD0E8), Color(hex: 0xCFEFF8)]),
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: pool)
        ))
        var streaks = Path()
        for index in 0..<40 {
            let x = fall.minX + fall.width * CGFloat(hash01(index, 10))
            let length = unit * CGFloat(0.06 + 0.1 * hash01(index, 11))
            let y = CGFloat((hash01(index, 12) + phase * (0.6 + 0.4 * hash01(index, 13))).truncatingRemainder(dividingBy: 1)) * (pool + length) - length
            streaks.addRect(CGRect(x: x, y: y, width: max(1, unit * 0.003), height: length))
        }
        graphics.fill(streaks, with: .color(.white.opacity(0.7)))

        // Pool.
        graphics.fill(Path(CGRect(x: 0, y: pool, width: size.width, height: size.height - pool)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2C6E78), Color(hex: 0x123A3E)]),
            startPoint: CGPoint(x: 0, y: pool), endPoint: CGPoint(x: 0, y: size.height)
        ))
        for ripple in ripples.rings {
            let age = frame.time - ripple.born
            let radius = unit * CGFloat(0.02 + age * 0.12)
            let center = CGPoint(x: size.width * CGFloat(ripple.x), y: pool + (size.height - pool) * CGFloat(ripple.y))
            graphics.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.3, width: radius * 2, height: radius * 0.6)), with: .color(.white.opacity(max(0, 0.35 * (1 - age / 2.5)))), lineWidth: max(1, unit * 0.002))
        }

        // Churning foam and rising mist at the foot of the falls.
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.025))
            for index in 0..<18 {
                let rise = (hash01(index, 20) + phase * 0.12).truncatingRemainder(dividingBy: 1)
                let point = CGPoint(x: fall.midX + fall.width * CGFloat(hash01(index, 21) * 1.8 - 0.9), y: pool - unit * 0.3 * CGFloat(rise))
                layer.fill(JungleTheme.disc(point, unit * CGFloat(0.03 + 0.05 * rise)), with: .color(.white.opacity(0.35 * (1 - rise))))
            }
            for index in 0..<10 {
                let point = CGPoint(x: fall.minX + fall.width * CGFloat(Double(index) / 9), y: pool + unit * 0.01 * CGFloat(sin(phase * 4 + Double(index))))
                layer.fill(JungleTheme.disc(point, unit * 0.035), with: .color(.white.opacity(0.8)))
            }
        }

        // Lily pads with glowing frogs, throats puffing on the beat.
        let pads: [(CGFloat, CGFloat, CGFloat)] = [(0.18, 0.8, 0.07), (0.75, 0.84, 0.08), (0.88, 0.74, 0.05), (0.3, 0.92, 0.05)]
        for (index, (px, py, r)) in pads.enumerated() {
            let center = CGPoint(x: size.width * px, y: size.height * py)
            var pad = Path(ellipseIn: CGRect(x: center.x - unit * r, y: center.y - unit * r * 0.35, width: unit * r * 2, height: unit * r * 0.7))
            pad.move(to: center)
            graphics.fill(pad, with: .color(Color(hex: 0x3E8E4A)))
            if index < 2 {
                drawFrog(in: &graphics, center: center + CGPoint(x: 0, y: -unit * 0.02), scale: unit * 0.05, puff: Double(audio.beatPulse) * (index == 0 ? 1 : (audio.beatCount % 2 == 0 ? 0.3 : 1)), glow: Double(audio.level))
            }
        }
    }

    private func drawFrog(in graphics: inout GraphicsContext, center: CGPoint, scale: CGFloat, puff: Double, glow: Double) {
        let body = JungleTheme.frogGlow.mix(with: JungleTheme.leaf, by: 0.4)
        var light = graphics
        light.blendMode = .plusLighter
        JungleTheme.glow(in: light, at: center, radius: scale * 2, color: JungleTheme.frogGlow, opacity: 0.15 + 0.3 * glow)
        graphics.fill(Path(ellipseIn: CGRect(x: center.x - scale * 0.7, y: center.y - scale * 0.35, width: scale * 1.4, height: scale * 0.8)), with: .color(body))
        for side: CGFloat in [-1, 1] {
            let eye = center + CGPoint(x: side * scale * 0.35, y: -scale * 0.35)
            graphics.fill(JungleTheme.disc(eye, scale * 0.2), with: .color(body))
            graphics.fill(JungleTheme.disc(eye, scale * 0.11), with: .color(Color(hex: 0xFFB000)))
            graphics.fill(Path(ellipseIn: CGRect(x: eye.x - scale * 0.03, y: eye.y - scale * 0.09, width: scale * 0.06, height: scale * 0.18)), with: .color(.black))
        }
        // Throat sac inflating on the beat.
        let sac = scale * CGFloat(0.12 + 0.35 * puff)
        let throat = center + CGPoint(x: 0, y: scale * 0.32)
        JungleTheme.glow(in: light, at: throat, radius: sac * 2.5, color: JungleTheme.frogGlow, opacity: 0.5 * puff)
        graphics.fill(Path(ellipseIn: CGRect(x: throat.x - sac, y: throat.y - sac * 0.8, width: sac * 2, height: sac * 1.6)), with: .color(Color(hex: 0xE8FFD8).opacity(0.9)))
    }
}

/// Ripples spreading across the pool, a few more on each beat.
private final class PoolRipples {
    struct Ring {
        var x: Double
        var y: Double
        var born: Double
    }

    private(set) var rings: [Ring] = []
    private var beatEdge = BeatEdge()
    private var lastIdle = 0.0

    func step(frame: AudioFrame) {
        if beatEdge.isNewBeat(frame.audio) {
            rings.append(Ring(x: .random(in: 0.35...0.65), y: .random(in: 0.05...0.3), born: frame.time))
        }
        if frame.time - lastIdle > 0.8 {
            lastIdle = frame.time
            rings.append(Ring(x: .random(in: 0.1...0.9), y: .random(in: 0.1...0.9), born: frame.time))
        }
        rings.removeAll { frame.time - $0.born > 2.5 }
    }
}
