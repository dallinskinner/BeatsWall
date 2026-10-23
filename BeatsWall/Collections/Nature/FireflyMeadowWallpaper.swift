//
//  FireflyMeadowWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct FireflyMeadowWallpaper: View {
    let context: WallpaperContext
    @State private var breeze = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.025)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.62
        let wind = breeze.advance(to: frame.time, speed: 0.8 + 1.6 * Double(audio.mid))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [NatureTheme.duskTop, NatureTheme.duskMid, NatureTheme.duskGlow]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        var stars = Path()
        for index in 0..<40 {
            let r = unit * 0.0016 * CGFloat(0.6 + hash01(index, 2))
            stars.addEllipse(in: CGRect(x: CGFloat(hash01(index, 0)) * size.width - r, y: CGFloat(hash01(index, 1)) * horizon * 0.35 - r, width: r * 2, height: r * 2))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.6)))

        // Hills and a tree line in silhouette.
        func ridge(base: CGFloat, height: CGFloat, frequency: Double, seed: Int, color: Color, bumps: Bool) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            var x: CGFloat = 0
            while x <= size.width + 4 {
                let s = Double(x / unit) * frequency
                var y = base - height * CGFloat(0.5 + 0.3 * sin(s + Double(seed)) + 0.2 * sin(s * 2.7 + Double(seed) * 3))
                if bumps { y -= height * 0.25 * CGFloat(abs(sin(s * 9 + Double(seed)))) }
                path.addLine(to: CGPoint(x: x, y: y))
                x += 4
            }
            path.addLine(to: CGPoint(x: size.width + 4, y: size.height))
            path.closeSubpath()
            graphics.fill(path, with: .color(color))
        }
        ridge(base: horizon, height: unit * 0.12, frequency: 2.2, seed: 1, color: Color(hex: 0x3A3554), bumps: false)
        ridge(base: horizon + unit * 0.03, height: unit * 0.1, frequency: 3.5, seed: 4, color: Color(hex: 0x1F2238), bumps: true)
        graphics.fill(Path(CGRect(x: 0, y: horizon + unit * 0.02, width: size.width, height: size.height)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1A2420), NatureTheme.grass]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
        ))

        drawFireflies(in: &graphics, size: size, unit: unit, horizon: horizon, frame: frame, front: false)

        // Grass: far blades first, swaying with the melody.
        let blades = context.isPreview ? 140 : 320
        var grassLayers = [Path](repeating: Path(), count: 3)
        for index in 0..<blades {
            let depth = Double(index) / Double(blades)
            let x = CGFloat(hash01(index, 31)) * (size.width + unit * 0.1) - unit * 0.05
            let base = horizon + (size.height - horizon) * CGFloat(0.15 + 0.9 * depth)
            let height = unit * CGFloat((0.04 + 0.08 * hash01(index, 32)) * (0.5 + depth))
            let bend = CGFloat(sin(wind + Double(x / unit) * 2.5 + hash01(index, 33)) * (0.25 + 0.5 * Double(audio.mid))) * height * 0.35
            let width = unit * 0.004 * CGFloat(0.6 + depth)
            var blade = Path()
            blade.move(to: CGPoint(x: x - width, y: base))
            blade.addQuadCurve(to: CGPoint(x: x + bend, y: base - height), control: CGPoint(x: x - width * 0.5, y: base - height * 0.6))
            blade.addQuadCurve(to: CGPoint(x: x + width, y: base), control: CGPoint(x: x + width * 0.5, y: base - height * 0.6))
            blade.closeSubpath()
            grassLayers[min(Int(depth * 3), 2)].addPath(blade)
        }
        graphics.fill(grassLayers[0], with: .color(Color(hex: 0x24332B)))
        graphics.fill(grassLayers[1], with: .color(Color(hex: 0x17241D)))
        graphics.fill(grassLayers[2], with: .color(NatureTheme.grass))

        drawFireflies(in: &graphics, size: size, unit: unit, horizon: horizon, frame: frame, front: true)
    }

    private func drawFireflies(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, horizon: CGFloat, frame: AudioFrame, front: Bool) {
        let audio = frame.audio
        let count = context.isPreview ? 40 : 80
        var light = graphics
        light.blendMode = .plusLighter
        for index in 0..<count where (index % 3 == 0) == front {
            let seed = hash01(index, 51)
            let t = frame.time * (0.08 + 0.1 * hash01(index, 52))
            let x = CGFloat(hash01(index, 53)) * size.width + unit * 0.12 * CGFloat(sin(t * 2.1 + seed * 9))
            let y = horizon - unit * 0.05 + (size.height - horizon) * CGFloat(0.8 * hash01(index, 54)) + unit * 0.06 * CGFloat(sin(t * 3.3 + seed * 5))
            // Each firefly blinks on its own rhythm; some flash together on the beat.
            let blink = pow(max(0, sin(frame.time * (0.6 + hash01(index, 55)) + seed * 20)), 6)
            let beatFlash = hash01(index, audio.beatCount) > 0.55 ? Double(audio.beatPulse) : 0
            let brightness = min(1, 0.15 + 0.85 * max(blink, beatFlash) * (0.6 + 0.6 * Double(audio.treble)))
            let scale = front ? 1.4 : 1.0
            let point = CGPoint(x: x, y: y)
            NatureTheme.glow(in: light, at: point, radius: unit * 0.025 * CGFloat(scale), color: NatureTheme.firefly, opacity: 0.5 * brightness)
            light.fill(NatureTheme.disc(point, unit * 0.0035 * CGFloat(scale)), with: .color(NatureTheme.firefly.mix(with: .white, by: 0.4).opacity(0.3 + 0.7 * brightness)))
        }
    }
}
