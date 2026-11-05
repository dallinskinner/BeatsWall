//
//  MainStageWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct MainStageWallpaper: View {
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
        let audio = frame.audio
        ConcertTheme.use(context)
        hype.update(time: frame.time, audio: audio)
        hype.cue(context.look?.startedAt)
        let unit = min(size.width, size.height)
        let beat = audio.beatProgress(at: frame.time)
        let bar = Int(beat / 4)
        let energy = hype.energy
        let palette = ConcertTheme.palette(context)
        let color = ConcertTheme.rigColor(bar: bar, palette: palette)
        let accent = ConcertTheme.rigColor(bar: bar, offset: 2, palette: palette)

        let stageWidth = min(size.width * 0.94, unit * 1.7)
        let stageLeft = (size.width - stageWidth) / 2
        let floorY = size.height * 0.64
        let trussY = size.height * 0.14

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [ConcertTheme.night, Color(hex: 0x140A24), ConcertTheme.night]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        var light = graphics
        light.blendMode = .plusLighter
        ConcertTheme.glow(in: light, at: CGPoint(x: size.width / 2, y: floorY - unit * 0.2), radius: unit * 0.9, color: color, opacity: 0.12 + 0.2 * energy + 0.25 * hype.dropPulse)

        // LED wall: the song's name as it starts and every eighth bar, the user's stage image on
        // every other bar, and otherwise visuals with a new look every bar.
        let wall = CGRect(x: size.width / 2 - stageWidth * 0.3, y: trussY + unit * 0.09, width: stageWidth * 0.6, height: floorY - trussY - unit * 0.16)
        graphics.fill(Path(wall), with: .color(Color(hex: 0x05030A)))
        let stageImage = StageImage.shared.image
        let pulse = Double(audio.beatPulse)
        if let look = context.look, let age = ConcertTheme.songAge(context, frame: frame), age < audio.beatLength * 8 || bar % 8 == 7 {
            if let stageImage {
                ConcertTheme.screenImage(stageImage, in: graphics, rect: wall, pulse: 0, brightness: 0.15)
            }
            ConcertTheme.glow(in: light, at: CGPoint(x: wall.midX, y: wall.midY), radius: wall.width * 0.5, color: color, opacity: 0.25 + 0.3 * pulse)
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: wall.midX, y: wall.midY - wall.height * 0.08), maxWidth: wall.width * 0.88, size: wall.height * CGFloat(0.22 + 0.03 * pulse), color: color, glow: 0.6 + 0.4 * pulse)
            ConcertTheme.marquee(look.artist, in: light, at: CGPoint(x: wall.midX, y: wall.midY + wall.height * 0.2), maxWidth: wall.width * 0.8, size: wall.height * 0.1, color: accent, glow: 0.6, weight: .bold)
        } else if let stageImage, bar.isMultiple(of: 2) {
            ConcertTheme.screenImage(stageImage, in: graphics, rect: wall, pulse: pulse, brightness: 0.75 + 0.25 * energy)
        } else {
            drawScreen(in: light, rect: wall, frame: frame, bar: bar, color: color, accent: accent)
        }
        // Side screens.
        for side in [-1.0, 1.0] {
            let width = stageWidth * 0.13
            let rect = CGRect(x: size.width / 2 + CGFloat(side) * stageWidth * 0.4 - width / 2, y: wall.minY + unit * 0.04, width: width, height: wall.height * 0.7)
            graphics.fill(Path(rect), with: .color(Color(hex: 0x05030A)))
            light.fill(Path(rect.insetBy(dx: unit * 0.004, dy: unit * 0.004)), with: .linearGradient(
                Gradient(colors: [accent.opacity(0.15 + 0.5 * Double(audio.beatPulse)), color.opacity(0.1 + 0.3 * energy)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
        }

        // Stage deck with a light strip along its edge.
        var deck = Path()
        deck.addLines([
            CGPoint(x: stageLeft, y: floorY), CGPoint(x: stageLeft + stageWidth, y: floorY),
            CGPoint(x: stageLeft + stageWidth + unit * 0.05, y: floorY + unit * 0.06), CGPoint(x: stageLeft - unit * 0.05, y: floorY + unit * 0.06),
        ])
        deck.closeSubpath()
        graphics.fill(deck, with: .color(ConcertTheme.stage))
        var strip = Path()
        strip.addLines([CGPoint(x: stageLeft - unit * 0.05, y: floorY + unit * 0.06), CGPoint(x: stageLeft + stageWidth + unit * 0.05, y: floorY + unit * 0.06)])
        light.stroke(strip, with: .color(color.opacity(0.4 + 0.6 * Double(audio.beatPulse))), lineWidth: unit * 0.004)

        // Truss and towers.
        var truss = Path()
        truss.addRect(CGRect(x: stageLeft, y: trussY, width: stageWidth, height: unit * 0.035))
        for side in [stageLeft, stageLeft + stageWidth - unit * 0.035] {
            truss.addRect(CGRect(x: side, y: trussY, width: unit * 0.035, height: floorY - trussY))
        }
        graphics.fill(truss, with: .color(Color(hex: 0x1A1626)))
        var lattice = Path()
        var x = stageLeft
        while x < stageLeft + stageWidth {
            lattice.move(to: CGPoint(x: x, y: trussY))
            lattice.addLine(to: CGPoint(x: x + unit * 0.035, y: trussY + unit * 0.035))
            x += unit * 0.035
        }
        graphics.stroke(lattice, with: .color(Color(hex: 0x2E2840)), lineWidth: max(1, unit * 0.002))

        // Moving heads: they sweep in tempo, pinch together as the song builds and fan
        // wide when it drops.
        let heads = 8
        let fan = 0.25 + 0.45 * hype.dropPulse
        for index in 0..<heads {
            let t = Double(index) / Double(heads - 1)
            let origin = CGPoint(x: stageLeft + stageWidth * CGFloat(0.08 + 0.84 * t), y: trussY + unit * 0.045)
            let sweep = ConcertTheme.motion(index: index, count: heads, beat: beat)
            let spreadOut = (t - 0.5) * 2 * fan
            let pinch = -(t - 0.5) * 0.9 * hype.build
            let angle = (sweep + spreadOut) * (1 - hype.build * 0.7) + pinch
            let beamColor = index.isMultiple(of: 2) ? color : accent
            ConcertTheme.beam(
                in: light, from: origin, angle: angle, length: size.height * 1.05, spread: 0.06 - 0.03 * hype.build,
                color: beamColor, intensity: 0.25 + 0.55 * energy + 0.3 * hype.build
            )
            graphics.fill(Path(roundedRect: CGRect(x: origin.x - unit * 0.012, y: origin.y - unit * 0.015, width: unit * 0.024, height: unit * 0.02), cornerRadius: unit * 0.004), with: .color(Color(hex: 0x2A2438)))
        }
        // Uplights from the deck fan open on the drop.
        for index in 0..<6 {
            let t = Double(index) / 5
            let origin = CGPoint(x: stageLeft + stageWidth * CGFloat(0.12 + 0.76 * t), y: floorY)
            let angle = .pi + (t - 0.5) * (0.5 + 0.9 * hype.dropPulse) + ConcertTheme.motion(index: index, count: 6, beat: beat / 2) * 0.33
            ConcertTheme.beam(in: light, from: origin, angle: angle, length: size.height * 0.75, spread: 0.035, color: accent, intensity: 0.15 + 0.5 * Double(audio.bass) * energy)
        }
        ConcertTheme.haze(in: light, rect: CGRect(x: 0, y: trussY, width: size.width, height: floorY - trussY + unit * 0.2), color: color, opacity: 0.05 + 0.12 * hype.build)

        // CO2 jets blast up from the deck when it drops.
        let age = hype.secondsSinceDrop
        if age < 1.6 {
            let rise = 1 - exp(-age * 6)
            let fade = 1 - smoothstep(0.4, 1.6, age)
            for index in 0..<4 {
                let base = CGPoint(x: stageLeft + stageWidth * CGFloat(0.2 + 0.2 * Double(index)), y: floorY)
                let height = unit * 0.45 * CGFloat(rise)
                var plume = Path()
                plume.move(to: base + CGPoint(x: -unit * 0.01, y: 0))
                plume.addQuadCurve(to: base + CGPoint(x: 0, y: -height), control: base + CGPoint(x: -unit * 0.07, y: -height * 0.6))
                plume.addQuadCurve(to: base + CGPoint(x: unit * 0.01, y: 0), control: base + CGPoint(x: unit * 0.07, y: -height * 0.6))
                plume.closeSubpath()
                light.fill(plume, with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.7 * fade), Color.white.opacity(0.05 * fade)]),
                    startPoint: base, endPoint: base + CGPoint(x: 0, y: -height)
                ))
            }
        }
        // Confetti cannons from both sides of the stage.
        let pieces = context.isReduced ? 60 : 180
        ConcertTheme.confetti(in: graphics, from: CGPoint(x: stageLeft + unit * 0.05, y: floorY), angle: 0.45, age: age, unit: unit, count: pieces, seed: hype.dropCount * 7)
        ConcertTheme.confetti(in: graphics, from: CGPoint(x: stageLeft + stageWidth - unit * 0.05, y: floorY), angle: -0.45, age: age, unit: unit, count: pieces, seed: hype.dropCount * 7 + 3)

        // The crowd, back rows lit by the stage.
        let rows: [(baseline: CGFloat, scale: CGFloat, count: Int, color: Color)] = [
            (size.height * 0.8, 0.12, 30, Color(hex: 0x120C1C)),
            (size.height * 0.9, 0.17, 20, Color(hex: 0x09060F)),
            (size.height * 1.02, 0.25, 12, ConcertTheme.crowd),
        ]
        for (index, row) in rows.enumerated() {
            let count = Int(Double(row.count) * Double(size.width / unit) * 0.6 + 2)
            ConcertTheme.crowd(
                in: graphics, size: size, unit: unit, baseline: row.baseline, scale: row.scale,
                count: context.isReduced ? count / 2 + 1 : count, seed: 40 + index * 10, color: row.color, audio: audio, beat: beat,
                handsUp: 0.15 + 0.5 * energy + 0.35 * hype.dropPulse, jump: 0.2 + 0.7 * energy
            )
        }

        // Strobes: on hard beats when the energy is up, and a burst on the drop.
        let beatFlash = energy > 0.6 && audio.secondsSinceBeat < 0.06 ? 0.5 : 0
        let dropFlash = age < 1.2 && sin(frame.time * 50) > 0.3 ? 0.8 : 0
        ConcertTheme.strobe(in: graphics, size: size, amount: max(beatFlash, dropFlash))
    }

    private func drawScreen(in light: GraphicsContext, rect: CGRect, frame: AudioFrame, bar: Int, color: Color, accent: Color) {
        let audio = frame.audio
        let pulse = Double(audio.beatPulse)
        var screen = light
        screen.clip(to: Path(rect))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        switch bar % 4 {
        case 0:
            // Mirrored spectrum bars.
            let bins = 16
            let width = rect.width / CGFloat(bins * 2)
            for bin in 0..<bins {
                let value = CGFloat(audio.spectrum[min(bin * 2, AudioFeatures.binCount - 1)])
                let height = rect.height * (0.05 + 0.9 * value)
                for side in [-1.0, 1.0] {
                    let x = center.x + CGFloat(side) * (CGFloat(bin) + 0.5) * width - width * 0.4
                    screen.fill(Path(CGRect(x: x, y: rect.maxY - height, width: width * 0.8, height: height)), with: .linearGradient(
                        Gradient(colors: [accent, color]), startPoint: CGPoint(x: x, y: rect.maxY), endPoint: CGPoint(x: x, y: rect.minY)
                    ))
                }
            }
        case 1:
            // Rings rushing outward on the beat.
            for ring in 0..<6 {
                let phase = (Double(ring) + audio.beatProgress(at: frame.time).truncatingRemainder(dividingBy: 1)) / 6
                let radius = rect.width * CGFloat(phase) * 0.7
                screen.stroke(ConcertTheme.disc(center, radius), with: .color((ring.isMultiple(of: 2) ? color : accent).opacity(1 - phase)), lineWidth: rect.height * 0.04 * CGFloat(1 + pulse))
            }
        case 2:
            // A checkerboard that inverts on every beat.
            let columns = 8
            let cell = rect.width / CGFloat(columns)
            let rowsCount = Int(rect.height / cell) + 1
            var cells = Path()
            for row in 0..<rowsCount {
                for column in 0..<columns where (row + column + audio.beatCount).isMultiple(of: 2) {
                    cells.addRect(CGRect(x: rect.minX + CGFloat(column) * cell, y: rect.minY + CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            screen.fill(cells, with: .color(color.opacity(0.35 + 0.6 * pulse)))
        default:
            // A starburst that spins with the tempo.
            let spokes = 18
            let spin = audio.beatProgress(at: frame.time) * 0.25
            var rays = Path()
            for index in 0..<spokes {
                let angle = Double(index) / Double(spokes) * 2 * .pi + spin
                let reach = rect.width
                rays.move(to: center)
                rays.addLine(to: center + CGPoint(x: cos(angle - 0.06) * reach, y: sin(angle - 0.06) * reach))
                rays.addLine(to: center + CGPoint(x: cos(angle + 0.06) * reach, y: sin(angle + 0.06) * reach))
                rays.closeSubpath()
            }
            screen.fill(rays, with: .color(accent.opacity(0.3 + 0.5 * pulse)))
            screen.fill(ConcertTheme.disc(center, rect.height * CGFloat(0.12 + 0.12 * Double(audio.bass))), with: .color(color))
        }
        // Flash the whole panel on the beat.
        screen.fill(Path(rect), with: .color(.white.opacity(0.12 * pulse)))
    }
}
