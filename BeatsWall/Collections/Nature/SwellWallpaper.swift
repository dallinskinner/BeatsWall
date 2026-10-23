//
//  SwellWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct SwellWallpaper: View {
    let context: WallpaperContext
    @State private var tide = PhaseClock()

    private static let layers = 6

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.02)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.5
        let phase = tide.advance(to: frame.time, speed: 0.7 + 1.2 * Double(audio.mid))
        let swell = 0.45 + 1.3 * Double(audio.bass)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [NatureTheme.night, NatureTheme.nightSky]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        var stars = Path()
        for index in 0..<80 {
            let r = unit * 0.0018 * CGFloat(0.5 + hash01(index, 2) + 0.5 * sin(frame.time * 2 + Double(index)))
            stars.addEllipse(in: CGRect(x: CGFloat(hash01(index, 0)) * size.width - r, y: CGFloat(hash01(index, 1)) * horizon * 0.8 - r, width: r * 2, height: r * 2))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.7)))
        let moon = CGPoint(x: size.width * 0.72, y: size.height * 0.2)
        let moonRadius = unit * 0.06
        NatureTheme.glow(in: graphics, at: moon, radius: moonRadius * (4 + Double(audio.level) * 2), color: NatureTheme.moon, opacity: 0.25)
        graphics.fill(NatureTheme.disc(moon, moonRadius), with: .color(NatureTheme.moon))

        // Wave layers, far to near. Nearer waves are taller, longer and faster.
        for layer in 0..<Self.layers {
            let depth = Double(layer) / Double(Self.layers - 1)
            let base = horizon + (size.height - horizon) * CGFloat(0.04 + 0.9 * pow(depth, 1.3))
            let amplitude = unit * CGFloat((0.004 + 0.022 * depth) * swell)
            let frequency = 2 * Double.pi / Double(unit * CGFloat(0.12 + 0.3 * depth))
            let speed = phase * (0.6 + 0.6 * depth)
            func height(_ x: CGFloat) -> CGFloat {
                let primary = sin(Double(x) * frequency + speed + Double(layer) * 1.7)
                let secondary = sin(Double(x) * frequency * 2.3 - speed * 1.3 + Double(layer))
                return base - amplitude * CGFloat(primary + 0.35 * secondary)
            }

            var crest = Path()
            let step = unit * 0.008
            var x: CGFloat = 0
            crest.move(to: CGPoint(x: 0, y: height(0)))
            while x <= size.width + step {
                x += step
                crest.addLine(to: CGPoint(x: x, y: height(x)))
            }
            var water = crest
            water.addLine(to: CGPoint(x: size.width + step, y: size.height))
            water.addLine(to: CGPoint(x: 0, y: size.height))
            water.closeSubpath()
            graphics.fill(water, with: .color(NatureTheme.farWater.mix(with: NatureTheme.nearWater, by: depth)))
            graphics.stroke(crest, with: .color(NatureTheme.foam.opacity(0.12 + 0.15 * depth)), lineWidth: max(1, unit * 0.002))

            // Foam glints on the crests, more with the treble.
            var foam = Path()
            var sample: CGFloat = 0
            var index = 0
            while sample < size.width {
                let peak = sin(Double(sample) * frequency + speed + Double(layer) * 1.7)
                if peak > 0.8, hash01(index * 13 + layer, Int(frame.time * 6)) < 0.15 + 0.6 * Double(audio.treble) {
                    let r = unit * 0.0025 * CGFloat(0.5 + depth)
                    foam.addEllipse(in: CGRect(x: sample - r, y: height(sample) - r, width: r * 2, height: r * 2))
                }
                sample += unit * 0.012
                index += 1
            }
            graphics.fill(foam, with: .color(NatureTheme.foam.opacity(0.85)))
        }

        // Moonlight path on the water.
        var path = Path()
        for row in 0..<28 {
            let t = Double(row) / 27
            let y = horizon + (size.height - horizon) * CGFloat(pow(t, 1.4)) + unit * 0.004
            let width = moonRadius * CGFloat((0.6 + 2.2 * t) * (0.5 + 0.5 * sin(phase * 2 + Double(row) * 1.9)))
            let shift = unit * 0.012 * CGFloat(sin(phase + Double(row) * 0.9)) * CGFloat(0.5 + Double(audio.mid))
            path.addRoundedRect(in: CGRect(x: moon.x - width / 2 + shift, y: y, width: width, height: unit * 0.004), cornerSize: CGSize(width: unit * 0.002, height: unit * 0.002))
        }
        var light = graphics
        light.blendMode = .plusLighter
        light.fill(path, with: .color(NatureTheme.moon.opacity(0.35)))
    }
}
