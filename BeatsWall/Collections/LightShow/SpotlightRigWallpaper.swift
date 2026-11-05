//
//  SpotlightRigWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// A wall of moving-head spotlights throwing patterned pools of light onto the floor.
struct SpotlightRigWallpaper: View {
    let context: WallpaperContext
    @State private var hype = HypeMeter()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ConcertTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        ConcertTheme.use(context)
        let audio = frame.audio
        hype.update(time: frame.time, audio: audio)
        hype.cue(context.look?.startedAt)
        let unit = min(size.width, size.height)
        let beat = audio.beatProgress(at: frame.time)
        let bar = Int(beat / 4)
        let pulse = Double(audio.beatPulse)
        let energy = hype.energy
        let palette = ConcertTheme.palette(context)
        let floorY = size.height * 0.84

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x05040A), Color(hex: 0x0B0814)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)
        ))
        graphics.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(Color(hex: 0x08060E)))
        var light = graphics
        light.blendMode = .plusLighter
        ConcertTheme.haze(in: light, rect: CGRect(x: 0, y: size.height * 0.1, width: size.width, height: floorY), color: ConcertTheme.rigColor(bar: bar, palette: palette), opacity: 0.04 + 0.08 * energy)

        // The rig: a grid of heads, three rows deep, fewer columns on a tall screen.
        let columns = size.width > size.height ? 5 : 3
        let rows = 3
        let count = columns * rows
        let gridWidth = min(size.width * 0.86, unit * 1.6)
        let left = (size.width - gridWidth) / 2
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let head = CGPoint(
                    x: left + gridWidth * (CGFloat(column) + 0.5) / CGFloat(columns),
                    y: size.height * (0.1 + 0.11 * CGFloat(row))
                )
                // Heads lean toward the middle and move as the desk says.
                let lean = Double((head.x - size.width / 2) / max(size.width, 1)) * -0.6
                let angle = lean + ConcertTheme.motion(index: index, count: count, beat: beat) * 0.9
                let color = ConcertTheme.rigColor(bar: bar, offset: column + row, palette: palette)
                    .mix(with: .white, by: 0.7 * hype.dropPulse)
                // The far rows are dimmer, and every other head fires on alternate beats.
                let fires = (index + audio.beatCount).isMultiple(of: 2) || energy > 0.6
                let intensity = (0.25 + 0.6 * energy + 0.3 * hype.dropPulse) * (fires ? 1 : 0.35) * (1 - 0.18 * Double(row))
                let length = (floorY - head.y) / CGFloat(max(cos(angle), 0.3))
                ConcertTheme.beam(in: light, from: head, angle: angle, length: length, spread: 0.07 - 0.03 * hype.build, color: color, intensity: intensity)

                // A gobo-patterned pool where the beam lands.
                let spot = head + CGPoint(x: sin(angle) * length, y: cos(angle) * length)
                guard spot.y > floorY - unit * 0.02 else { continue }
                var pool = light
                pool.translateBy(x: spot.x, y: spot.y)
                pool.scaleBy(x: 1, y: 0.28)
                let radius = unit * CGFloat(0.05 + 0.03 * pulse)
                pool.fill(ConcertTheme.disc(.zero, radius), with: .radialGradient(
                    Gradient(colors: [color.opacity(0.7 * intensity), color.opacity(0)]), center: .zero, startRadius: 0, endRadius: radius
                ))
                var gobo = Path()
                for petal in 0..<6 {
                    let spin = Double(petal) / 6 * 2 * .pi + beat * 0.5
                    gobo.addPath(ConcertTheme.disc(CGPoint(x: cos(spin) * radius * 0.6, y: sin(spin) * radius * 0.6), radius * 0.16))
                }
                pool.fill(gobo, with: .color(color.mix(with: .white, by: 0.5).opacity(0.8 * intensity)))
                graphics.fill(ConcertTheme.disc(head, unit * 0.012), with: .color(Color(hex: 0x1C1828)))
                ConcertTheme.glow(in: light, at: head, radius: unit * 0.025, color: color, opacity: intensity)
            }
        }

        if let look = context.look {
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: size.width / 2, y: floorY + (size.height - floorY) * 0.55), maxWidth: gridWidth * 0.8, size: unit * 0.05, color: ConcertTheme.rigColor(bar: bar, palette: palette), glow: 0.4 + 0.3 * pulse)
        }
        ConcertTheme.strobe(in: graphics, size: size, amount: energy > 0.7 && audio.secondsSinceBeat < 0.05 ? 0.4 : (hype.secondsSinceDrop < 0.3 ? 0.7 : 0))
    }
}
