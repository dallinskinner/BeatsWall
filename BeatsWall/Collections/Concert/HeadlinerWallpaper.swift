//
//  HeadlinerWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct HeadlinerWallpaper: View {
    let context: WallpaperContext
    @State private var hype = HypeMeter()
    @State private var smoke = PhaseClock()

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
        hype.update(time: frame.time, audio: audio)
        hype.cue(context.look?.startedAt)
        let unit = min(size.width, size.height)
        let beat = audio.beatProgress(at: frame.time)
        let energy = hype.energy
        let drift = smoke.advance(to: frame.time, speed: 0.4 + 0.6 * energy)
        let center = size.width / 2
        let floorY = size.height * 0.7
        let palette = ConcertTheme.palette(context)
        let warm = palette == ConcertTheme.rig
            ? ConcertTheme.pyro.mix(with: ConcertTheme.magenta, by: 0.5 + 0.5 * sin(beat * .pi / 8))
            : ConcertTheme.rigColor(bar: Int(beat / 8), palette: palette)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ConcertTheme.night))
        var light = graphics
        light.blendMode = .plusLighter

        // Backlight wall glowing behind the band, then a grid of PAR cans that chase the spectrum.
        ConcertTheme.glow(in: light, at: CGPoint(x: center, y: floorY - unit * 0.15), radius: unit * 0.85, color: warm, opacity: 0.25 + 0.35 * energy + 0.3 * hype.dropPulse)
        let columns = max(6, Int(size.width / (unit * 0.12)))
        let rows = 3
        let spacing = size.width / CGFloat(columns)
        for row in 0..<rows {
            for column in 0..<columns {
                let bin = (column * AudioFeatures.binCount / columns + row * 3) % AudioFeatures.binCount
                let on = Double(audio.spectrum[bin])
                let point = CGPoint(x: spacing * (CGFloat(column) + 0.5), y: size.height * 0.1 + CGFloat(row) * unit * 0.1)
                let color = (row + column + audio.beatCount / 4).isMultiple(of: 3) ? ConcertTheme.amber : warm
                graphics.fill(ConcertTheme.disc(point, unit * 0.02), with: .color(Color(hex: 0x1A1420)))
                ConcertTheme.glow(in: light, at: point, radius: unit * CGFloat(0.03 + 0.05 * on), color: color, opacity: 0.2 + 0.8 * on * energy)
            }
        }
        // The user's stage image on a backdrop screen behind the band.
        if let stageImage = StageImage.shared.image {
            let top = size.height * 0.1 + unit * 0.27
            let width = min(size.width * 0.62, unit * 1.1)
            let backdrop = CGRect(x: center - width / 2, y: top, width: width, height: floorY - unit * 0.12 - top)
            graphics.fill(Path(backdrop.insetBy(dx: -unit * 0.01, dy: -unit * 0.01)), with: .color(Color(hex: 0x0A0710)))
            ConcertTheme.screenImage(stageImage, in: graphics, rect: backdrop, pulse: Double(audio.beatPulse) * 0.6, brightness: 0.5 + 0.35 * energy)
        }
        // The artist's name in lights across the rig.
        if let look = context.look {
            let y = size.height * 0.1 + unit * 0.1
            let plate = CGRect(x: center - min(size.width * 0.36, unit * 0.6), y: y - unit * 0.055, width: min(size.width * 0.72, unit * 1.2), height: unit * 0.11)
            graphics.fill(Path(roundedRect: plate, cornerRadius: unit * 0.01), with: .color(Color(hex: 0x0A0710)))
            ConcertTheme.marquee(look.artist, in: light, at: CGPoint(x: center, y: y), maxWidth: plate.width * 0.9, size: unit * 0.075, color: warm, glow: 0.6 + 0.4 * Double(audio.beatPulse))
        }
        // Followspot on the singer.
        let singerX = center + min(unit * 0.24, size.width * 0.22)
        ConcertTheme.beam(in: light, from: CGPoint(x: center + unit * 0.3, y: -unit * 0.05), angle: atan2(singerX - (center + unit * 0.3), floorY), length: floorY * 1.15, spread: 0.07, color: .white, intensity: 0.35 + 0.3 * energy)
        for side in [-1.0, 1.0] {
            let origin = CGPoint(x: center + CGFloat(side) * size.width * 0.45, y: size.height * 0.05)
            let angle = -side * (0.5 + 0.25 * sin(beat * .pi / 2))
            ConcertTheme.beam(in: light, from: origin, angle: angle, length: size.height, spread: 0.08, color: warm, intensity: 0.2 + 0.5 * Double(audio.mid))
        }

        // Stage floor and drum riser.
        graphics.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(ConcertTheme.stage))
        let riser = CGRect(x: center - unit * 0.22, y: floorY - unit * 0.12, width: unit * 0.44, height: unit * 0.12)
        graphics.fill(Path(riser), with: .color(Color(hex: 0x0A0710)))
        light.stroke(Path(CGRect(x: riser.minX, y: riser.minY, width: riser.width, height: 0)), with: .color(warm.opacity(0.4 + 0.6 * Double(audio.beatPulse))), lineWidth: unit * 0.004)

        let silhouette = Color(hex: 0x050308)
        drawDrummer(in: graphics, light: light, at: CGPoint(x: center, y: riser.minY), unit: unit, audio: audio, color: silhouette, glow: warm)
        drawGuitarist(in: graphics, at: CGPoint(x: center - min(unit * 0.42, size.width * 0.3), y: floorY), unit: unit, audio: audio, beat: beat, color: silhouette)
        drawSinger(in: graphics, at: CGPoint(x: singerX, y: floorY + unit * 0.02), unit: unit, audio: audio, beat: beat, raise: hype.dropPulse, color: silhouette)

        // Flame columns along the front: a few on big bass hits, all of them on the drop.
        let flames = 4
        let hit = energy > 0.5 ? pow(Double(audio.beatPulse), 1.5) * Double(audio.bass) : 0
        for index in 0..<flames {
            let fires = hype.dropPulse > 0.2 || hash01(index, audio.beatCount) < 0.5
            let strength = max(hype.dropPulse, fires ? hit : 0)
            guard strength > 0.05 else { continue }
            let t = (Double(index) + 0.5) / Double(flames)
            let base = CGPoint(x: size.width * CGFloat(0.08 + 0.84 * t), y: floorY + unit * 0.01)
            drawFlame(in: light, base: base, height: unit * CGFloat(0.55 * strength), width: unit * 0.07, time: frame.time, seed: index)
            ConcertTheme.glow(in: light, at: base, radius: unit * 0.5 * CGFloat(strength), color: ConcertTheme.pyro, opacity: 0.4 * strength)
        }
        // A curtain of sparks from the top truss after a drop.
        let age = hype.secondsSinceDrop
        ConcertTheme.sparkRain(
            in: light, span: 0...size.width, top: size.height * 0.04, floor: floorY, age: age, unit: unit,
            count: context.isReduced ? 60 : 220, intensity: 1 - smoothstep(3, 6, age)
        )

        // Smoke rolling across the stage.
        for index in 0..<5 {
            let x = (CGFloat(drift * 0.05 + hash01(index, 21)).truncatingRemainder(dividingBy: 1.4) - 0.2) * size.width
            let point = CGPoint(x: x, y: floorY - unit * CGFloat(0.02 + 0.08 * hash01(index, 22)))
            var puff = light
            puff.translateBy(x: point.x, y: point.y)
            puff.scaleBy(x: 2.4, y: 0.6)
            ConcertTheme.glow(in: puff, at: .zero, radius: unit * 0.2, color: warm.mix(with: .white, by: 0.6), opacity: 0.08 + 0.1 * energy)
        }

        ConcertTheme.crowd(
            in: graphics, size: size, unit: unit, baseline: size.height * 1.03, scale: 0.24,
            count: Int(size.width / unit * 7) + 2, seed: 70, color: ConcertTheme.crowd, audio: audio, beat: beat,
            handsUp: 0.25 + 0.5 * energy + 0.3 * hype.dropPulse, jump: 0.15 + 0.6 * energy
        )
        let flash = energy > 0.7 && audio.secondsSinceBeat < 0.05 ? 0.35 : 0
        ConcertTheme.strobe(in: graphics, size: size, amount: max(flash, age < 0.25 ? 0.7 * (1 - age * 4) : 0))
    }

    /// A filled torso from the hips up to the shoulders, so figures read as people, not sticks.
    private func torso(_ path: inout Path, hip: CGPoint, neck: CGPoint, hipWidth: CGFloat, shoulderWidth: CGFloat) {
        path.move(to: hip + CGPoint(x: -hipWidth / 2, y: 0))
        path.addLine(to: hip + CGPoint(x: hipWidth / 2, y: 0))
        path.addQuadCurve(to: neck + CGPoint(x: shoulderWidth / 2, y: 0), control: CGPoint(x: (hip.x + neck.x) / 2 + shoulderWidth * 0.55, y: (hip.y + neck.y) / 2))
        path.addLine(to: neck + CGPoint(x: -shoulderWidth / 2, y: 0))
        path.addQuadCurve(to: hip + CGPoint(x: -hipWidth / 2, y: 0), control: CGPoint(x: (hip.x + neck.x) / 2 - shoulderWidth * 0.55, y: (hip.y + neck.y) / 2))
        path.closeSubpath()
    }

    private func limb(_ path: inout Path, _ points: CGPoint...) {
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
    }

    private func drawDrummer(in graphics: GraphicsContext, light: GraphicsContext, at seat: CGPoint, unit: CGFloat, audio: AudioFeatures, color: Color, glow: Color) {
        let s = unit * 0.22
        var body = Path()
        var limbs = Path()
        let hip = seat + CGPoint(x: 0, y: -s * 0.15)
        let neck = hip + CGPoint(x: 0, y: -s * 0.4)
        body.addPath(ConcertTheme.disc(neck + CGPoint(x: 0, y: -s * 0.12), s * 0.1))
        torso(&body, hip: hip, neck: neck, hipWidth: s * 0.22, shoulderWidth: s * 0.3)
        // Sticks come down on each beat, alternating hands.
        let swing = min(audio.secondsSinceBeat / max(audio.beatLength * 0.5, 0.1), 1)
        for side in [-1.0, 1.0] {
            let leads = (audio.beatCount.isMultiple(of: 2) ? 1.0 : -1.0) == side
            let lift = leads ? swing : 1 - swing * 0.5
            let shoulder = neck + CGPoint(x: s * 0.12 * side, y: s * 0.05)
            let hand = shoulder + CGPoint(x: s * 0.28 * side, y: s * CGFloat(0.22 - 0.3 * lift))
            let elbow = twoBoneJoint(from: shoulder, to: hand, upper: s * 0.2, lower: s * 0.2, bend: side)
            limb(&limbs, shoulder, elbow, hand)
            let stickAngle = side * (0.4 + 1.1 * lift)
            limb(&limbs, hand, hand + CGPoint(x: sin(stickAngle) * s * 0.25, y: -cos(stickAngle) * s * 0.25))
        }
        graphics.stroke(limbs, with: .color(color), style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round, lineJoin: .round))
        graphics.fill(body, with: .color(color))

        // Kit in front of him: kick drum with a glowing head, toms and cymbals.
        let kick = seat + CGPoint(x: 0, y: s * 0.12)
        graphics.fill(ConcertTheme.disc(kick, s * 0.3), with: .color(color))
        ConcertTheme.glow(in: light, at: kick, radius: s * CGFloat(0.28 + 0.1 * audio.bass), color: glow, opacity: 0.25 + 0.6 * Double(audio.bass))
        light.stroke(ConcertTheme.disc(kick, s * 0.26), with: .color(glow.opacity(0.3 + 0.7 * Double(audio.beatPulse))), lineWidth: s * 0.02)
        var kit = Path()
        for side in [-1.0, 1.0] {
            kit.addEllipse(in: CGRect(x: kick.x + s * CGFloat(0.35 * side) - s * 0.12, y: kick.y - s * 0.35, width: s * 0.24, height: s * 0.16))
            let cymbal = kick + CGPoint(x: s * 0.65 * side, y: -s * 0.75)
            kit.addEllipse(in: CGRect(x: cymbal.x - s * 0.2, y: cymbal.y - s * 0.03, width: s * 0.4, height: s * 0.06))
            kit.move(to: cymbal)
            kit.addLine(to: cymbal + CGPoint(x: 0, y: s * 0.9))
            light.fill(Path(ellipseIn: CGRect(x: cymbal.x - s * 0.2, y: cymbal.y - s * 0.03, width: s * 0.4, height: s * 0.06)), with: .color(ConcertTheme.amber.opacity(0.5 * Double(audio.treble))))
        }
        graphics.stroke(kit, with: .color(color), lineWidth: s * 0.02)
        graphics.fill(kit, with: .color(color))
    }

    private func drawGuitarist(in graphics: GraphicsContext, at foot: CGPoint, unit: CGFloat, audio: AudioFeatures, beat: Double, color: Color) {
        let s = unit * 0.42
        var limbs = Path()
        var body = Path()
        // Wide stance, headbanging with the bass on every beat.
        let hip = foot + CGPoint(x: 0, y: -s * 0.45)
        let bang = Double(audio.beatPulse) * Double(audio.bass)
        let neck = hip + CGPoint(x: s * CGFloat(0.06 * bang), y: -s * 0.38)
        let head = neck + CGPoint(x: s * CGFloat(0.03 + 0.08 * bang), y: -s * CGFloat(0.1 - 0.06 * bang))
        limb(&limbs, foot + CGPoint(x: -s * 0.18, y: 0), hip, foot + CGPoint(x: s * 0.2, y: 0))
        torso(&body, hip: hip, neck: neck, hipWidth: s * 0.12, shoulderWidth: s * 0.17)
        body.addPath(ConcertTheme.disc(head, s * 0.07))
        // Hair flying with the headbang.
        var hair = Path()
        hair.move(to: head + CGPoint(x: -s * 0.05, y: -s * 0.02))
        hair.addQuadCurve(to: head + CGPoint(x: s * CGFloat(0.06 + 0.1 * bang), y: s * CGFloat(0.12 + 0.05 * bang)), control: head + CGPoint(x: s * 0.12, y: -s * 0.05))
        // Guitar across the body.
        let neckEnd = neck + CGPoint(x: -s * 0.35, y: -s * 0.08)
        let bodyCenter = hip + CGPoint(x: s * 0.05, y: -s * 0.05)
        body.addEllipse(in: CGRect(x: bodyCenter.x - s * 0.13, y: bodyCenter.y - s * 0.09, width: s * 0.26, height: s * 0.18))
        limb(&limbs, bodyCenter, neckEnd)
        // Fret hand on the neck, strumming hand on the strings.
        let strum = sin(beat * .pi * 2) * 0.03
        limb(&limbs, neck + CGPoint(x: -s * 0.04, y: s * 0.04), neck + CGPoint(x: -s * 0.2, y: s * 0.06), neckEnd + CGPoint(x: s * 0.05, y: s * 0.02))
        limb(&limbs, neck + CGPoint(x: s * 0.04, y: s * 0.04), hip + CGPoint(x: s * 0.15, y: -s * 0.15), bodyCenter + CGPoint(x: s * 0.04, y: s * CGFloat(strum)))
        graphics.stroke(limbs, with: .color(color), style: StrokeStyle(lineWidth: s * 0.065, lineCap: .round, lineJoin: .round))
        graphics.stroke(hair, with: .color(color), style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round))
        graphics.fill(body, with: .color(color))
    }

    private func drawSinger(in graphics: GraphicsContext, at foot: CGPoint, unit: CGFloat, audio: AudioFeatures, beat: Double, raise: Double, color: Color) {
        let s = unit * 0.5
        var limbs = Path()
        var body = Path()
        let sway = CGFloat(sin(beat * .pi / 2)) * s * 0.02
        let hip = foot + CGPoint(x: sway, y: -s * 0.45)
        let neck = hip + CGPoint(x: sway, y: -s * 0.36)
        let head = neck + CGPoint(x: 0, y: -s * 0.09)
        limb(&limbs, foot + CGPoint(x: -s * 0.08, y: 0), hip, foot + CGPoint(x: s * 0.09, y: 0))
        torso(&body, hip: hip, neck: neck, hipWidth: s * 0.1, shoulderWidth: s * 0.15)
        body.addPath(ConcertTheme.disc(head, s * 0.065))
        // Mic stand, with one hand on the mic and the other thrown up for the drop.
        let mic = head + CGPoint(x: s * 0.07, y: s * 0.03)
        var stand = Path()
        limb(&stand, foot + CGPoint(x: s * 0.12, y: 0), mic + CGPoint(x: s * 0.03, y: s * 0.03))
        graphics.stroke(stand, with: .color(color), lineWidth: s * 0.012)
        limb(&limbs, neck + CGPoint(x: s * 0.04, y: s * 0.03), neck + CGPoint(x: s * 0.12, y: s * 0.12), mic)
        let up = max(raise, 0.3 * Double(audio.mid))
        let hand = neck + CGPoint(x: -s * CGFloat(0.22 - 0.1 * up), y: s * CGFloat(0.15 - 0.45 * up))
        limb(&limbs, neck + CGPoint(x: -s * 0.04, y: s * 0.03), neck + CGPoint(x: -s * 0.16, y: s * CGFloat(0.08 - 0.15 * up)), hand)
        body.addPath(ConcertTheme.disc(hand, s * 0.025))
        graphics.stroke(limbs, with: .color(color), style: StrokeStyle(lineWidth: s * 0.055, lineCap: .round, lineJoin: .round))
        graphics.fill(body, with: .color(color))
    }

    private func drawFlame(in light: GraphicsContext, base: CGPoint, height: CGFloat, width: CGFloat, time: Double, seed: Int) {
        let layers: [(scale: CGFloat, color: Color)] = [(1, ConcertTheme.pyro), (0.75, ConcertTheme.amber), (0.45, Color(hex: 0xFFF1C8))]
        for (index, layer) in layers.enumerated() {
            let flicker = CGFloat(0.85 + 0.15 * sin(time * (13 + Double(index) * 3) + Double(seed)))
            let h = height * layer.scale * flicker
            let half = width * layer.scale / 2
            let lick = CGFloat(sin(time * 7 + Double(seed) * 2)) * width * 0.3
            var flame = Path()
            flame.move(to: base + CGPoint(x: -half, y: 0))
            flame.addQuadCurve(to: base + CGPoint(x: lick, y: -h), control: base + CGPoint(x: -half * 1.6, y: -h * 0.5))
            flame.addQuadCurve(to: base + CGPoint(x: half, y: 0), control: base + CGPoint(x: half * 1.6 + lick * 0.5, y: -h * 0.5))
            flame.closeSubpath()
            light.fill(flame, with: .linearGradient(
                Gradient(colors: [layer.color.opacity(0.95), layer.color.opacity(0.1)]),
                startPoint: base, endPoint: base + CGPoint(x: 0, y: -h)
            ))
        }
    }
}
