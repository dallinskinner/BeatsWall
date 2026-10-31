//
//  LightsUpWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct LightsUpWallpaper: View {
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
        hype.update(time: frame.time, audio: audio)
        hype.cue(context.look?.startedAt)
        let unit = min(size.width, size.height)
        let palette = ConcertTheme.palette(context)
        let beat = audio.beatProgress(at: frame.time)
        let energy = hype.energy
        let center = size.width / 2
        let rimY = size.height * 0.36
        let fieldY = size.height * 0.62

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x050A22), Color(hex: 0x1A1046), Color(hex: 0x3A1550)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: rimY)
        ))
        var light = graphics
        light.blendMode = .plusLighter
        var stars = Path()
        for index in 0..<(context.isReduced ? 50 : 120) {
            let point = CGPoint(x: CGFloat(hash01(index, 1)) * size.width, y: CGFloat(hash01(index, 2)) * rimY * 0.8)
            let twinkle = 0.5 + 0.5 * sin(frame.time * (1 + 2 * hash01(index, 3)) + Double(index))
            stars.addPath(ConcertTheme.disc(point, unit * 0.0018 * CGFloat(0.6 + twinkle)))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.7)))

        // Fireworks over the rim: one may go up on each loud beat, and a volley on the drop.
        for back in 0..<4 {
            let count = audio.beatCount - back
            guard hash01(count, 7) < energy * 0.8 else { continue }
            let age = (audio.secondsSinceBeat.isFinite ? audio.secondsSinceBeat : 0) + Double(back) * audio.beatLength
            let point = CGPoint(x: size.width * CGFloat(0.15 + 0.7 * hash01(count, 8)), y: rimY * CGFloat(0.2 + 0.5 * hash01(count, 9)))
            ConcertTheme.firework(in: light, at: point, age: age, radius: unit * CGFloat(0.12 + 0.1 * hash01(count, 10)), color: ConcertTheme.rigColor(bar: count, palette: palette), seed: count, count: context.isReduced ? 18 : 36)
        }
        let dropAge = hype.secondsSinceDrop
        for index in 0..<6 {
            let age = dropAge - Double(index) * 0.18
            let point = CGPoint(x: size.width * CGFloat(0.1 + 0.8 * hash01(index, hype.dropCount + 50)), y: rimY * CGFloat(0.15 + 0.45 * hash01(index, hype.dropCount + 60)))
            ConcertTheme.firework(in: light, at: point, age: age, radius: unit * 0.2, color: ConcertTheme.rigColor(bar: index + hype.dropCount, palette: palette), seed: index * 13 + hype.dropCount, count: context.isReduced ? 20 : 44)
        }

        // The stadium bowl: far stands curving down to the field, with floodlight towers.
        var bowl = Path()
        bowl.move(to: CGPoint(x: 0, y: rimY - unit * 0.05))
        bowl.addQuadCurve(to: CGPoint(x: size.width, y: rimY - unit * 0.05), control: CGPoint(x: center, y: rimY + unit * 0.08))
        bowl.addLine(to: CGPoint(x: size.width, y: size.height))
        bowl.addLine(to: CGPoint(x: 0, y: size.height))
        bowl.closeSubpath()
        graphics.fill(bowl, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x120B22), Color(hex: 0x07050D)]),
            startPoint: CGPoint(x: 0, y: rimY), endPoint: CGPoint(x: 0, y: size.height)
        ))
        for side in [-1.0, 1.0] {
            let tower = CGPoint(x: center + CGFloat(side) * size.width * 0.42, y: rimY - unit * 0.18)
            graphics.stroke(Path { $0.addLines([tower, tower + CGPoint(x: 0, y: unit * 0.15)]) }, with: .color(Color(hex: 0x120B22)), lineWidth: unit * 0.008)
            ConcertTheme.beam(in: light, from: tower, angle: -side * 0.55, length: size.height * 0.8, spread: 0.12, color: Color(hex: 0xCFE3FF), intensity: 0.15 + 0.15 * energy)
            ConcertTheme.glow(in: light, at: tower, radius: unit * 0.06, color: .white, opacity: 0.7)
        }

        // Far stage with a big screen pulsing to the music.
        // It grows to show the user's stage image or the song's name.
        let stageImage = StageImage.shared.image
        let showsMore = stageImage != nil || context.look != nil
        let screenSize = showsMore ? CGSize(width: unit * 0.44, height: unit * 0.25) : CGSize(width: unit * 0.32, height: unit * 0.13)
        let screen = CGRect(x: center - screenSize.width / 2, y: fieldY - unit * 0.07 - screenSize.height, width: screenSize.width, height: screenSize.height)
        graphics.fill(Path(screen.insetBy(dx: -unit * 0.006, dy: -unit * 0.006)), with: .color(Color(hex: 0x0A0712)))
        let screenColor = ConcertTheme.rigColor(bar: Int(beat / 4), palette: palette)
        if let stageImage {
            ConcertTheme.screenImage(stageImage, in: graphics, rect: screen, pulse: Double(audio.beatPulse), brightness: context.look == nil ? 0.8 : 0.2)
        } else {
            light.fill(Path(screen), with: .radialGradient(
                Gradient(colors: [screenColor.opacity(0.4 + 0.5 * Double(audio.beatPulse)), screenColor.opacity(0.15)]),
                center: CGPoint(x: screen.midX, y: screen.midY), startRadius: 0, endRadius: screen.width * 0.6
            ))
        }
        if let look = context.look {
            ConcertTheme.marquee(look.title, in: light, at: CGPoint(x: screen.midX, y: screen.midY - screen.height * 0.1), maxWidth: screen.width * 0.85, size: screen.height * 0.2, color: screenColor, glow: 0.8)
            ConcertTheme.marquee(look.artist, in: light, at: CGPoint(x: screen.midX, y: screen.midY + screen.height * 0.2), maxWidth: screen.width * 0.75, size: screen.height * 0.1, color: screenColor, glow: 0.6, weight: .bold)
        }
        var wave = Path()
        for step in 0...40 {
            let t = Double(step) / 40
            let bin = min(Int(t * Double(AudioFeatures.binCount)), AudioFeatures.binCount - 1)
            let y = screen.midY - screen.height * 0.4 * CGFloat(audio.spectrum[bin]) * CGFloat(sin(t * .pi * 6 + beat * .pi))
            let point = CGPoint(x: screen.minX + screen.width * CGFloat(t), y: y)
            step == 0 ? wave.move(to: point) : wave.addLine(to: point)
        }
        if !showsMore {
            light.stroke(wave, with: .color(.white.opacity(0.8)), lineWidth: unit * 0.003)
        }
        graphics.fill(Path(CGRect(x: center - unit * 0.24, y: fieldY - unit * 0.06, width: unit * 0.48, height: unit * 0.04)), with: .color(Color(hex: 0x0A0712)))
        for index in 0..<5 {
            let t = Double(index) / 4
            let origin = CGPoint(x: center + unit * CGFloat(0.4 * (t - 0.5)), y: fieldY - unit * 0.06)
            ConcertTheme.beam(in: light, from: origin, angle: .pi + (t - 0.5) * 0.8 + sin(beat * .pi / 2) * 0.2, length: unit * 0.5, spread: 0.03, color: screenColor, intensity: 0.2 + 0.6 * energy)
        }
        ConcertTheme.glow(in: light, at: CGPoint(x: center, y: fieldY - unit * 0.1), radius: unit * 0.5, color: screenColor, opacity: 0.12 + 0.2 * energy)

        // A sea of phone lights across the stands and the field, swaying side to side every two beats.
        let phones = context.isReduced ? 260 : 900
        var lights = Path()
        var warmLights = Path()
        let swayAmount = 0.4 + 0.6 * Double(audio.mid)
        for index in 0..<phones {
            let depth = pow(hash01(index, 11), 0.7)
            let y = rimY + (size.height * 0.95 - rimY) * CGFloat(depth)
            let x = CGFloat(hash01(index, 12)) * (size.width + unit * 0.1) - unit * 0.05
            let near = CGFloat(0.4 + 1.6 * depth)
            let sway = sin(beat * .pi / 2 + Double(x / unit) * 0.6) * swayAmount
            let point = CGPoint(x: x + CGFloat(sway) * unit * 0.012 * near, y: y - CGFloat(abs(sway)) * unit * 0.004 * near)
            let radius = unit * 0.0028 * near * CGFloat(0.8 + 0.4 * hash01(index, 13))
            if hash01(index, 14) < 0.12 {
                warmLights.addPath(ConcertTheme.disc(point, radius))
            } else {
                lights.addPath(ConcertTheme.disc(point, radius))
            }
        }
        let brightness = 0.55 + 0.25 * energy + 0.2 * Double(audio.beatPulse)
        var glowing = light
        glowing.addFilter(.blur(radius: unit * 0.004))
        glowing.fill(lights, with: .color(Color(hex: 0xBFD8FF).opacity(brightness)))
        glowing.fill(warmLights, with: .color(ConcertTheme.amber.opacity(brightness)))
        light.fill(lights, with: .color(.white.opacity(brightness)))
        light.fill(warmLights, with: .color(Color(hex: 0xFFE6B0).opacity(brightness)))

        // Front row holding their phones up.
        let hands = ConcertTheme.crowd(
            in: graphics, size: size, unit: unit, baseline: size.height * 1.04, scale: 0.26,
            count: Int(size.width / unit * 6) + 2, seed: 90, color: ConcertTheme.crowd, audio: audio, beat: beat,
            handsUp: 0.55 + 0.35 * energy, jump: 0.1 + 0.4 * energy
        )
        for hand in hands {
            let phone = CGRect(x: hand.x - unit * 0.012, y: hand.y - unit * 0.04, width: unit * 0.024, height: unit * 0.042)
            graphics.fill(Path(roundedRect: phone, cornerRadius: unit * 0.004), with: .color(Color(hex: 0x16141C)))
            ConcertTheme.glow(in: light, at: CGPoint(x: phone.midX, y: phone.minY + unit * 0.006), radius: unit * 0.05, color: .white, opacity: 0.5 * brightness)
        }
    }
}
