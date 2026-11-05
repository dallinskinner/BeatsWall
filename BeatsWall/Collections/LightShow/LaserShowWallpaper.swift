//
//  LaserShowWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Lasers alone in black fog over a glossy floor, with a rippling sheet of laser for a sky on
/// the drops.
struct LaserShowWallpaper: View {
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
        ConcertTheme.use(context)
        let audio = frame.audio
        hype.update(time: frame.time, audio: audio)
        hype.cue(context.look?.startedAt)
        let unit = min(size.width, size.height)
        let beat = audio.beatProgress(at: frame.time)
        let bar = Int(beat / 4)
        let pulse = Double(audio.beatPulse)
        let energy = hype.energy
        let rotation = spin.advance(to: frame.time, speed: (0.2 + 0.8 * energy + 2 * hype.dropPulse) * context.rig.speed)
        let palette = ConcertTheme.palette(context)
        let isHouseRig = palette == ConcertTheme.rig
        let primary = isHouseRig ? (bar.isMultiple(of: 2) ? ConcertTheme.laserGreen : ConcertTheme.ice) : ConcertTheme.rigColor(bar: bar, palette: palette)
        let secondary = isHouseRig ? (bar.isMultiple(of: 2) ? ConcertTheme.magenta : ConcertTheme.laserGreen) : ConcertTheme.rigColor(bar: bar, offset: 1, palette: palette)
        let floorY = size.height * 0.72
        let emitter = CGPoint(x: size.width / 2, y: floorY)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x020205)))
        var light = graphics
        light.blendMode = .plusLighter
        ConcertTheme.haze(in: light, rect: CGRect(x: 0, y: 0, width: size.width, height: floorY), color: primary, opacity: 0.05 + 0.1 * energy + 0.12 * hype.build)

        // The sky: wavy sheets of laser that ripple in on drops and big builds.
        let sky = min(1, hype.dropPulse * 1.4 + hype.build * 0.6)
        if sky > 0.02 {
            let lines = context.isReduced ? 5 : 9
            let width = max(1, unit * 0.002)
            for line in 0..<lines {
                var wave = Path()
                let baseY = size.height * (0.08 + 0.025 * CGFloat(line))
                var x: CGFloat = 0
                while x <= size.width + 8 {
                    let y = baseY + unit * 0.03 * CGFloat(sin(Double(x / unit) * 5 + frame.time * 2.2 + Double(line) * 0.5))
                    x == 0 ? wave.move(to: CGPoint(x: x, y: y)) : wave.addLine(to: CGPoint(x: x, y: y))
                    x += 8
                }
                let color = line.isMultiple(of: 2) ? primary : secondary
                light.stroke(wave, with: .color(color.opacity(0.15 * sky)), lineWidth: width * 5)
                light.stroke(wave, with: .color(color.mix(with: .white, by: 0.4).opacity(0.8 * sky)), lineWidth: width)
            }
        }

        ConcertTheme.laserShow(
            in: light, size: size, origin: emitter, beat: beat, rotation: rotation, beatLength: audio.beatLength,
            hype: hype, pulse: pulse, primary: primary, secondary: secondary, reduced: context.isReduced
        )

        // Glossy floor that mirrors the show.
        let floor = CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)
        graphics.fill(Path(floor), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x0A0A14), Color(hex: 0x020205)]),
            startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: size.height)
        ))
        var mirror = light
        mirror.clip(to: Path(floor))
        mirror.translateBy(x: 0, y: floorY * 2)
        mirror.scaleBy(x: 1, y: -1)
        mirror.opacity = 0.22
        ConcertTheme.laserShow(
            in: mirror, size: size, origin: emitter, beat: beat, rotation: rotation, beatLength: audio.beatLength,
            hype: hype, pulse: pulse, primary: primary, secondary: secondary, reduced: true
        )
        var edge = Path()
        edge.addLines([CGPoint(x: 0, y: floorY), CGPoint(x: size.width, y: floorY)])
        light.stroke(edge, with: .color(primary.opacity(0.25 + 0.4 * pulse)), lineWidth: max(1, unit * 0.002))
        ConcertTheme.glow(in: light, at: emitter, radius: unit * CGFloat(0.06 + 0.06 * pulse), color: .white, opacity: 0.6 + 0.4 * pulse)

        if let look = context.look {
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: size.width / 2, y: floorY + (size.height - floorY) * 0.55), maxWidth: size.width * 0.7, size: unit * 0.05, color: primary, glow: 0.5 + 0.4 * pulse)
        }

        let eighth = (beat * 2).truncatingRemainder(dividingBy: 1)
        ConcertTheme.strobe(in: graphics, size: size, amount: hype.secondsSinceDrop < audio.beatLength * 4 && eighth < 0.1 ? 0.8 : 0)
    }
}
