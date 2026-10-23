//
//  VinylRoomWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct VinylRoomWallpaper: View {
    let context: WallpaperContext
    @State private var platter = PhaseClock()

    private static let bulbColors = [LofiTheme.lamp, LofiTheme.pink, LofiTheme.teal, Color(hex: 0xFFE08A)]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(LofiTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let shelfY = size.height * 0.66
        let center = size.width / 2

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x4A3B5C), Color(hex: 0x3A2F4C)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: shelfY)
        ))

        // Posters.
        let leftPoster = CGRect(x: size.width * 0.12, y: size.height * 0.2, width: unit * 0.22, height: unit * 0.3)
        graphics.fill(Path(roundedRect: leftPoster, cornerRadius: unit * 0.004), with: .color(LofiTheme.cream))
        graphics.fill(LofiTheme.ellipse(CGPoint(x: leftPoster.midX, y: leftPoster.minY + leftPoster.height * 0.4), unit * 0.06, unit * 0.06), with: .color(LofiTheme.clay))
        for row in 0..<3 {
            graphics.fill(Path(CGRect(x: leftPoster.minX + unit * 0.025, y: leftPoster.minY + leftPoster.height * (0.68 + 0.08 * CGFloat(row)), width: leftPoster.width - unit * 0.05, height: unit * 0.008)), with: .color(LofiTheme.teal.opacity(0.8)))
        }
        let rightPoster = CGRect(x: size.width * 0.88 - unit * 0.2, y: size.height * 0.24, width: unit * 0.2, height: unit * 0.24)
        graphics.fill(Path(roundedRect: rightPoster, cornerRadius: unit * 0.004), with: .color(LofiTheme.teal))
        var wave = Path()
        wave.move(to: CGPoint(x: rightPoster.minX + unit * 0.02, y: rightPoster.midY))
        for step in 0...20 {
            let x = rightPoster.minX + unit * 0.02 + (rightPoster.width - unit * 0.04) * CGFloat(step) / 20
            wave.addLine(to: CGPoint(x: x, y: rightPoster.midY + unit * 0.03 * CGFloat(sin(Double(step) * 0.9))))
        }
        graphics.stroke(wave, with: .color(LofiTheme.cream), lineWidth: unit * 0.008)

        drawFairyLights(in: &graphics, size: size, unit: unit, audio: audio, time: frame.time)

        // Cabinet.
        graphics.fill(Path(CGRect(x: 0, y: shelfY, width: size.width, height: unit * 0.03)), with: .color(LofiTheme.wood))
        graphics.fill(Path(CGRect(x: 0, y: shelfY + unit * 0.03, width: size.width, height: size.height)), with: .color(LofiTheme.woodDark))
        var drawers = Path()
        for x: CGFloat in [0.25, 0.5, 0.75] {
            drawers.addRect(CGRect(x: size.width * x - unit * 0.002, y: shelfY + unit * 0.05, width: unit * 0.004, height: size.height))
        }
        graphics.fill(drawers, with: .color(Color(hex: 0x553620)))

        // Speakers with woofers that push out on the bass.
        for side: CGFloat in [-1, 1] {
            let box = CGRect(x: center + side * unit * 0.48 - unit * 0.09, y: shelfY - unit * 0.3, width: unit * 0.18, height: unit * 0.3)
            graphics.fill(Path(roundedRect: box, cornerRadius: unit * 0.012), with: .color(Color(hex: 0x2A2238)))
            let woofer = CGPoint(x: box.midX, y: box.maxY - unit * 0.09)
            let push = 1 + 0.08 * CGFloat(audio.bass) + 0.04 * CGFloat(audio.beatPulse)
            graphics.fill(LofiTheme.ellipse(woofer, unit * 0.065, unit * 0.065), with: .color(Color(hex: 0x1A1524)))
            graphics.fill(LofiTheme.ellipse(woofer, unit * 0.055 * push, unit * 0.055 * push), with: .color(Color(hex: 0x3A3048)))
            graphics.fill(LofiTheme.ellipse(woofer, unit * 0.022 * push, unit * 0.022 * push), with: .color(Color(hex: 0x4E425E)))
            let tweeter = CGPoint(x: box.midX, y: box.minY + unit * 0.06)
            graphics.fill(LofiTheme.ellipse(tweeter, unit * 0.025, unit * 0.025), with: .color(Color(hex: 0x1A1524)))
            graphics.fill(LofiTheme.ellipse(tweeter, unit * 0.014 * (1 + 0.15 * CGFloat(audio.treble)), unit * 0.014 * (1 + 0.15 * CGFloat(audio.treble))), with: .color(Color(hex: 0x4E425E)))
        }

        // Turntable, seen from slightly above.
        let plinth = CGRect(x: center - unit * 0.26, y: shelfY - unit * 0.2, width: unit * 0.52, height: unit * 0.2)
        graphics.fill(Path(roundedRect: plinth.offsetBy(dx: 0, dy: unit * 0.015), cornerRadius: unit * 0.02), with: .color(Color(hex: 0x3A2618)))
        graphics.fill(Path(roundedRect: plinth, cornerRadius: unit * 0.02), with: .color(Color(hex: 0x5A3A2A)))
        let spindle = CGPoint(x: plinth.minX + plinth.width * 0.42, y: plinth.midY)
        let rx = unit * 0.17, ry = unit * 0.075
        graphics.fill(LofiTheme.ellipse(spindle, rx * 1.04, ry * 1.04), with: .color(Color(hex: 0x2A2A2E)))
        graphics.fill(LofiTheme.ellipse(spindle, rx, ry), with: .color(Color(hex: 0x121216)))
        var grooves = Path()
        for ring in 0..<7 {
            let scale = 0.45 + 0.08 * CGFloat(ring)
            grooves.addEllipse(in: CGRect(x: spindle.x - rx * scale, y: spindle.y - ry * scale, width: rx * scale * 2, height: ry * scale * 2))
        }
        graphics.stroke(grooves, with: .color(.white.opacity(0.06)), lineWidth: max(1, unit * 0.0015))
        // Static sheen: the light doesn't spin with the record.
        var sheen = Path()
        sheen.addArc(center: .zero, radius: 1, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
        var sheenContext = graphics
        sheenContext.translateBy(x: spindle.x, y: spindle.y)
        sheenContext.scaleBy(x: rx * 0.8, y: ry * 0.8)
        sheenContext.stroke(sheen, with: .color(.white.opacity(0.12)), lineWidth: 0.12)

        // Label spinning at 33⅓ RPM.
        let rotation = platter.advance(to: frame.time, speed: 2 * .pi * 33.3 / 60)
        graphics.fill(LofiTheme.ellipse(spindle, rx * 0.3, ry * 0.3), with: .color(LofiTheme.clay))
        for mark in 0..<2 {
            let angle = rotation + Double(mark) * .pi
            let point = spindle + CGPoint(x: cos(angle) * rx * 0.2, y: sin(angle) * ry * 0.2)
            graphics.fill(LofiTheme.ellipse(point, rx * 0.05, ry * 0.05), with: .color(LofiTheme.cream))
        }
        graphics.fill(LofiTheme.ellipse(spindle, unit * 0.004, unit * 0.003), with: .color(.white))

        // Tonearm.
        let pivot = CGPoint(x: plinth.maxX - unit * 0.06, y: plinth.minY + unit * 0.04)
        graphics.fill(LofiTheme.ellipse(pivot, unit * 0.02, unit * 0.014), with: .color(Color(hex: 0xB9C0C9)))
        var arm = Path()
        let needle = spindle + CGPoint(x: rx * 0.7, y: ry * 0.35)
        arm.addLines([pivot, pivot + CGPoint(x: -unit * 0.02, y: unit * 0.07), needle])
        graphics.stroke(arm, with: .color(Color(hex: 0xB9C0C9)), style: StrokeStyle(lineWidth: unit * 0.006, lineCap: .round, lineJoin: .round))
        graphics.fill(Path(roundedRect: CGRect(x: needle.x - unit * 0.012, y: needle.y - unit * 0.008, width: unit * 0.024, height: unit * 0.014), cornerRadius: unit * 0.003), with: .color(Color(hex: 0x2A2A2E)))
    }

    private func drawFairyLights(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, audio: AudioFeatures, time: Double) {
        let bulbs = 28
        let top = size.height * 0.08
        let sag = size.height * 0.08
        func point(_ t: Double) -> CGPoint {
            let x = size.width * CGFloat(t)
            let curve = 1 - pow(2 * t - 1, 2)
            return CGPoint(x: x, y: top + sag * CGFloat(curve) + unit * 0.01 * CGFloat(sin(t * 18)))
        }
        var wire = Path()
        wire.move(to: point(0))
        for step in 1...60 { wire.addLine(to: point(Double(step) / 60)) }
        graphics.stroke(wire, with: .color(LofiTheme.ink.opacity(0.7)), lineWidth: max(1, unit * 0.002))

        var light = graphics
        light.blendMode = .plusLighter
        for index in 0..<bulbs {
            let position = point((Double(index) + 0.5) / Double(bulbs)) + CGPoint(x: 0, y: unit * 0.012)
            let twinkle = 0.5 + 0.5 * sin(time * (1.5 + 3 * hash01(index, 9)) + Double(index))
            let beat = hash01(index, audio.beatCount) > 0.6 ? Double(audio.beatPulse) : 0
            let brightness = min(1, 0.35 + 0.4 * twinkle * (0.4 + Double(audio.treble)) + 0.5 * beat)
            let color = Self.bulbColors[index % Self.bulbColors.count]
            LofiTheme.glow(in: light, at: position, radius: unit * 0.035, color: color, opacity: 0.45 * brightness)
            light.fill(LofiTheme.ellipse(position, unit * 0.006, unit * 0.008), with: .color(color.mix(with: .white, by: 0.3).opacity(0.4 + 0.6 * brightness)))
        }
    }
}
