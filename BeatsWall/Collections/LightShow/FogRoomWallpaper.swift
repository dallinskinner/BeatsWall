//
//  FogRoomWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Beams from six angles cutting through thick, rolling fog. They open wide as a song builds
/// and narrow to bright pinpoints when it drops.
struct FogRoomWallpaper: View {
    let context: WallpaperContext
    @State private var hype = HypeMeter()
    @State private var drift = PhaseClock()

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
        let roll = drift.advance(to: frame.time, speed: 0.3 + 0.5 * energy)
        let palette = ConcertTheme.palette(context)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.55)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x040308)))
        var light = graphics
        light.blendMode = .plusLighter

        // Rolling fog, lit faintly by the room. Thicker with the desk's fog setting.
        let fog = context.rig.fog * 2
        let puffs = context.isReduced ? 6 : 12
        for index in 0..<puffs {
            let x = (CGFloat(roll * 0.03 * (0.5 + hash01(index, 1)) + hash01(index, 2)).truncatingRemainder(dividingBy: 1.4) - 0.2) * size.width
            let y = size.height * CGFloat(0.25 + 0.65 * hash01(index, 3)) + unit * 0.04 * CGFloat(sin(roll * 0.4 + Double(index)))
            var puff = light
            puff.translateBy(x: x, y: y)
            puff.scaleBy(x: 2.2, y: 0.8)
            let color = ConcertTheme.rigColor(bar: bar, offset: index, palette: palette).mix(with: .white, by: 0.7)
            ConcertTheme.glow(in: puff, at: .zero, radius: unit * 0.22, color: color, opacity: (0.05 + 0.06 * energy) * fog)
        }

        // Six fixtures: two high on each side and one low in each bottom corner.
        let fixtures: [(x: CGFloat, y: CGFloat)] = [(0.02, 0.05), (0.3, -0.02), (0.7, -0.02), (0.98, 0.05), (0.0, 0.95), (1.0, 0.95)]
        let spread = hype.dropPulse > 0.3 ? 0.015 : 0.04 + 0.08 * hype.build
        for (index, fixture) in fixtures.enumerated() {
            let origin = CGPoint(x: size.width * fixture.x, y: size.height * fixture.y)
            let toCenter = center - origin
            let aim = atan2(toCenter.x, toCenter.y) + ConcertTheme.motion(index: index, count: fixtures.count, beat: beat) * 0.6
            let color = ConcertTheme.rigColor(bar: bar, offset: index % 3, palette: palette).mix(with: .white, by: 0.5 * hype.dropPulse)
            let intensity = (0.3 + 0.5 * energy + 0.4 * hype.dropPulse) * (0.75 + 0.25 * pulse) * (0.6 + 0.4 * fog)
            ConcertTheme.beam(in: light, from: origin, angle: aim, length: hypot(size.width, size.height) * 0.9, spread: spread, color: color, intensity: intensity)
        }

        // Dust glinting in the light.
        var dust = Path()
        for index in 0..<(context.isReduced ? 60 : 160) {
            let x = CGFloat((hash01(index, 7) + roll * 0.004 * hash01(index, 8)).truncatingRemainder(dividingBy: 1)) * size.width
            let y = CGFloat((hash01(index, 9) - roll * 0.003 * hash01(index, 10)).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * size.height
            dust.addPath(ConcertTheme.disc(CGPoint(x: x, y: y), unit * 0.0015))
        }
        light.fill(dust, with: .color(.white.opacity(0.25 + 0.3 * energy)))

        ConcertTheme.strobe(in: graphics, size: size, amount: hype.secondsSinceDrop < 0.25 ? 0.6 : 0)
    }
}
