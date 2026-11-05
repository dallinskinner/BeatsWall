//
//  LaserRaveWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct LaserRaveWallpaper: View {
    let context: WallpaperContext
    @State private var hype = HypeMeter()
    @State private var spin = PhaseClock()

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
        let rotation = spin.advance(to: frame.time, speed: 0.2 + 0.8 * energy + 2 * hype.dropPulse)
        let booth = CGPoint(x: size.width / 2, y: size.height * 0.56)
        let palette = ConcertTheme.palette(context)
        let isHouseRig = palette == ConcertTheme.rig
        let primary = isHouseRig ? (bar.isMultiple(of: 2) ? ConcertTheme.laserGreen : ConcertTheme.magenta) : ConcertTheme.rigColor(bar: bar, palette: palette)
        let secondary = isHouseRig ? (bar.isMultiple(of: 2) ? ConcertTheme.ice : ConcertTheme.laserGreen) : ConcertTheme.rigColor(bar: bar, offset: 1, palette: palette)

        // A dark warehouse: girders and tall windows, barely visible through the fog.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x040308)))
        var girders = Path()
        let bays = max(4, Int(size.width / (unit * 0.3)))
        for index in 0...bays {
            let x = size.width * CGFloat(index) / CGFloat(bays)
            girders.addRect(CGRect(x: x - unit * 0.008, y: 0, width: unit * 0.016, height: booth.y))
            if index < bays {
                let window = CGRect(x: x + unit * 0.04, y: size.height * 0.12, width: size.width / CGFloat(bays) - unit * 0.08, height: size.height * 0.25)
                graphics.fill(Path(window), with: .color(Color(hex: 0x0C0A18)))
            }
        }
        girders.addRect(CGRect(x: 0, y: size.height * 0.07, width: size.width, height: unit * 0.014))
        graphics.fill(girders, with: .color(Color(hex: 0x0E0C16)))

        // The user's stage image on a screen behind the DJ, under the lasers.
        if let stageImage = StageImage.shared.image {
            let width = min(size.width * 0.5, unit * 0.7)
            let screen = CGRect(x: booth.x - width / 2, y: booth.y - unit * 0.1 - width * 9 / 16, width: width, height: width * 9 / 16)
            graphics.fill(Path(screen.insetBy(dx: -unit * 0.008, dy: -unit * 0.008)), with: .color(Color(hex: 0x0B0912)))
            ConcertTheme.screenImage(stageImage, in: graphics, rect: screen, pulse: Double(audio.beatPulse), brightness: 0.55 + 0.35 * energy)
        }

        var light = graphics
        light.blendMode = .plusLighter
        // Fog thickens and glows as the song builds.
        ConcertTheme.haze(in: light, rect: CGRect(x: 0, y: size.height * 0.05, width: size.width, height: size.height * 0.85), color: primary, opacity: 0.04 + 0.08 * energy + 0.12 * hype.build)
        ConcertTheme.glow(in: light, at: booth, radius: unit * (0.4 + 0.3 * CGFloat(hype.build)), color: primary, opacity: 0.15 + 0.25 * energy)

        ConcertTheme.laserShow(
            in: light, size: size, origin: booth, beat: beat, rotation: rotation, beatLength: audio.beatLength,
            hype: hype, pulse: Double(audio.beatPulse), primary: primary, secondary: secondary, reduced: context.isReduced
        )

        // DJ booth with the DJ, hands up on the drop.
        let deck = CGRect(x: booth.x - unit * 0.12, y: booth.y, width: unit * 0.24, height: unit * 0.08)
        let silhouette = Color(hex: 0x030206)
        var dj = Path()
        let bob = CGFloat(Double(audio.beatPulse)) * unit * 0.006
        dj.addPath(ConcertTheme.disc(CGPoint(x: booth.x, y: booth.y - unit * 0.075 + bob), unit * 0.022))
        dj.addRoundedRect(in: CGRect(x: booth.x - unit * 0.045, y: booth.y - unit * 0.05 + bob, width: unit * 0.09, height: unit * 0.07), cornerSize: CGSize(width: unit * 0.02, height: unit * 0.02))
        var arms = Path()
        let raise = max(hype.dropPulse, hype.build * 0.6)
        for side in [-1.0, 1.0] {
            let shoulder = CGPoint(x: booth.x + CGFloat(side) * unit * 0.035, y: booth.y - unit * 0.04 + bob)
            let down = CGPoint(x: booth.x + CGFloat(side) * unit * 0.06, y: booth.y + unit * 0.005)
            let up = CGPoint(x: booth.x + CGFloat(side) * unit * 0.07, y: booth.y - unit * 0.14)
            arms.move(to: shoulder)
            arms.addLine(to: CGPoint(x: raise.lerp(down.x, up.x), y: raise.lerp(down.y, up.y)))
        }
        graphics.stroke(arms, with: .color(silhouette), style: StrokeStyle(lineWidth: unit * 0.014, lineCap: .round))
        graphics.fill(dj, with: .color(silhouette))
        graphics.fill(Path(deck), with: .color(Color(hex: 0x0B0912)))
        light.stroke(Path(CGRect(x: deck.minX, y: deck.minY, width: deck.width, height: 0)), with: .color(primary.opacity(0.5 + 0.5 * Double(audio.beatPulse))), lineWidth: unit * 0.003)
        if let look = context.look {
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: deck.midX, y: deck.midY), maxWidth: deck.width * 0.9, size: deck.height * 0.4, color: primary, glow: 0.7 + 0.3 * Double(audio.beatPulse))
        }

        // The crowd, packed and jumping.
        let rows: [(baseline: CGFloat, scale: CGFloat, count: Int, color: Color)] = [
            (size.height * 0.8, 0.14, 24, Color(hex: 0x0A0812)),
            (size.height * 0.92, 0.2, 16, Color(hex: 0x06050B)),
            (size.height * 1.05, 0.28, 10, ConcertTheme.crowd),
        ]
        for (index, row) in rows.enumerated() {
            let count = Int(Double(row.count) * Double(size.width / unit) * 0.6 + 2)
            ConcertTheme.crowd(
                in: graphics, size: size, unit: unit, baseline: row.baseline, scale: row.scale,
                count: context.isReduced ? count / 2 + 1 : count, seed: 120 + index * 10, color: row.color, audio: audio, beat: beat,
                handsUp: 0.2 + 0.4 * energy + 0.4 * hype.dropPulse, jump: 0.3 + 0.7 * energy
            )
        }

        // Strobe: eighth notes through the first bars after the drop, then on hard beats.
        let eighth = (beat * 2).truncatingRemainder(dividingBy: 1)
        let dropStrobe = hype.secondsSinceDrop < audio.beatLength * 8 && eighth < 0.1 ? 0.9 : 0
        let beatStrobe = energy > 0.75 && audio.secondsSinceBeat < 0.04 ? 0.4 : 0
        ConcertTheme.strobe(in: graphics, size: size, amount: max(dropStrobe, beatStrobe))
    }
}
