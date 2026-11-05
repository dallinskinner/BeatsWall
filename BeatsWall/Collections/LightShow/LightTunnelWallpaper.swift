//
//  LightTunnelWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// A first-person rush through arches of LED light: a new arch arrives on every beat.
struct LightTunnelWallpaper: View {
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
        let beat = audio.beatProgress(at: frame.time) * context.rig.speed
        let pulse = Double(audio.beatPulse)
        let palette = ConcertTheme.palette(context)
        let vanish = CGPoint(x: size.width / 2, y: size.height * 0.5)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x020106)))
        var light = graphics
        light.blendMode = .plusLighter
        ConcertTheme.glow(in: light, at: vanish, radius: unit * 0.35, color: ConcertTheme.rigColor(bar: Int(beat / 4), palette: palette), opacity: 0.25 + 0.3 * hype.energy)

        // Arches from far to near. Each beat, every arch moves one step closer and a new one
        // appears in the distance.
        let arches = context.isReduced ? 10 : 16
        let step = beat.rounded(.down)
        let travel = beat - step
        for slot in stride(from: arches - 1, through: 0, by: -1) {
            let depth = (Double(slot) + 1 - smoothstep(0, 0.6, travel)) / Double(arches)
            let scale = CGFloat(0.06 / (depth * depth + 0.012))
            guard scale < 30 else { continue }
            let identity = Int(step) + arches - slot
            let halfWidth = unit * 0.5 * scale * 0.5
            let height = unit * 0.5 * scale * 0.75
            var arch = Path()
            arch.move(to: vanish + CGPoint(x: -halfWidth, y: height * 0.5))
            arch.addLine(to: vanish + CGPoint(x: -halfWidth, y: -height * 0.2))
            arch.addQuadCurve(to: vanish + CGPoint(x: halfWidth, y: -height * 0.2), control: vanish + CGPoint(x: 0, y: -height * 0.95))
            arch.addLine(to: vanish + CGPoint(x: halfWidth, y: height * 0.5))
            // Near arches are bright; the newest one flashes on its beat.
            let nearness = 1 - depth
            let color = ConcertTheme.rigColor(bar: identity, palette: palette).mix(with: .white, by: 0.8 * hype.dropPulse)
            let brightness = (0.15 + 0.85 * nearness) * (0.55 + 0.45 * hype.energy) * (slot == arches - 1 ? 0.4 + 0.6 * pulse : 1)
            let width = max(1, unit * 0.006 * scale * 0.4)
            light.stroke(arch, with: .color(color.opacity(0.18 * brightness)), style: StrokeStyle(lineWidth: width * 6, lineCap: .round))
            // LED dots chase along each arch.
            light.stroke(arch, with: .color(color.mix(with: .white, by: 0.3).opacity(brightness)), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [width * 1.2, width * 1.4], dashPhase: CGFloat(beat * 8) * width))
        }

        // The floor: lines rushing toward you.
        var lanes = Path()
        for lane in -4...4 {
            lanes.move(to: vanish + CGPoint(x: CGFloat(lane) * unit * 0.01, y: unit * 0.02))
            lanes.addLine(to: CGPoint(x: vanish.x + CGFloat(lane) * size.width * 0.35, y: size.height))
        }
        light.stroke(lanes, with: .color(ConcertTheme.rigColor(bar: Int(beat / 4), offset: 2, palette: palette).opacity(0.12 + 0.2 * pulse)), lineWidth: max(1, unit * 0.002))

        if let look = context.look, let age = ConcertTheme.songAge(context, frame: frame), age < audio.beatLength * 8 {
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: vanish.x, y: size.height * 0.88), maxWidth: unit * 0.7, size: unit * 0.055, color: ConcertTheme.rigColor(bar: 0, palette: palette), glow: 0.8)
        }
        ConcertTheme.strobe(in: graphics, size: size, amount: hype.secondsSinceDrop < 0.35 ? 1 - hype.secondsSinceDrop * 2 : 0)
    }
}
