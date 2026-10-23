//
//  RamenAlleyWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RamenAlleyWallpaper: View {
    let context: WallpaperContext
    @State private var sway = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(TokyoTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let phase = sway.advance(to: frame.time, speed: 0.8 + 1.5 * Double(audio.mid))
        let floor = size.height * 0.8
        let vanish = CGPoint(x: size.width / 2, y: size.height * 0.46)
        let farHalf = unit * 0.12

        // The far end of the alley: a sliver of hazy sky and a street light.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x0B0D18)))
        let opening = CGRect(x: vanish.x - farHalf, y: 0, width: farHalf * 2, height: vanish.y + unit * 0.05)
        graphics.fill(Path(opening), with: .linearGradient(
            Gradient(colors: [TokyoTheme.night, TokyoTheme.haze]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: opening.maxY)
        ))

        // Walls converging on the opening.
        for side: CGFloat in [-1, 1] {
            var wall = Path()
            let farX = vanish.x + side * farHalf
            let nearX = side < 0 ? 0 : size.width
            wall.addLines([CGPoint(x: farX, y: 0), CGPoint(x: nearX, y: 0), CGPoint(x: nearX, y: size.height), CGPoint(x: farX, y: opening.maxY)])
            wall.closeSubpath()
            graphics.fill(wall, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0C0D18)]),
                startPoint: CGPoint(x: farX, y: 0), endPoint: CGPoint(x: nearX, y: 0)
            ))
            // Pipes and AC units on the walls.
            var clutter = Path()
            for index in 0..<4 {
                let t = CGFloat(0.25 + 0.17 * Double(index))
                let x = farX + (nearX - farX) * t
                let y = size.height * CGFloat(0.15 + 0.12 * hash01(index, side < 0 ? 1 : 2))
                let s = unit * 0.06 * (0.4 + t)
                clutter.addRect(CGRect(x: x - s / 2, y: y, width: s, height: s * 0.7))
            }
            clutter.addRect(CGRect(x: farX + (nearX - farX) * 0.55, y: 0, width: unit * 0.012, height: size.height))
            graphics.fill(clutter, with: .color(Color(hex: 0x23253A)))
        }

        // Signs on the walls.
        TokyoTheme.drawSign(in: graphics, rect: CGRect(x: size.width * 0.08, y: size.height * 0.12, width: unit * 0.09, height: unit * 0.32), glyphCount: 4, vertical: true, seed: 5, color: TokyoTheme.pink, brightness: 0.4 + 0.6 * Double(audio.spectrum[6]))
        TokyoTheme.drawSign(in: graphics, rect: CGRect(x: size.width * 0.86, y: size.height * 0.2, width: unit * 0.08, height: unit * 0.26), glyphCount: 3, vertical: true, seed: 9, color: TokyoTheme.cyan, brightness: 0.4 + 0.6 * Double(audio.spectrum[18]))

        // Wet ground reflecting the warm stall.
        var ground = Path()
        ground.addLines([CGPoint(x: vanish.x - farHalf, y: opening.maxY), CGPoint(x: vanish.x + farHalf, y: opening.maxY), CGPoint(x: size.width, y: size.height), CGPoint(x: 0, y: size.height)])
        ground.closeSubpath()
        graphics.fill(ground, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1A1626), Color(hex: 0x0A0B12)]),
            startPoint: CGPoint(x: 0, y: opening.maxY), endPoint: CGPoint(x: 0, y: size.height)
        ))

        drawStall(in: &graphics, size: size, unit: unit, floor: floor, phase: phase, frame: frame)
        drawLanterns(in: &graphics, size: size, unit: unit, phase: phase, frame: frame)
        drawVendingMachine(in: &graphics, rect: CGRect(x: size.width * 0.78, y: floor - unit * 0.34, width: unit * 0.17, height: unit * 0.34), unit: unit, frame: frame)
        drawCat(in: &graphics, base: CGPoint(x: size.width * 0.17, y: floor + unit * 0.04), unit: unit, frame: frame)
        TokyoTheme.drawRain(in: &graphics, size: size, time: frame.time, density: 0.15 + 0.3 * Double(audio.level), slant: 0.05)
    }

    private func drawStall(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, floor: CGFloat, phase: Double, frame: AudioFrame) {
        let audio = frame.audio
        let width = unit * 0.5
        let left = size.width / 2 - width / 2
        let roof = floor - unit * 0.38
        let warmth = 0.55 + 0.35 * Double(audio.level)

        var glow = graphics
        glow.blendMode = .plusLighter
        glow.fill(Path(ellipseIn: CGRect(x: left - unit * 0.2, y: roof - unit * 0.05, width: width + unit * 0.4, height: unit * 0.65)), with: .radialGradient(
            Gradient(colors: [TokyoTheme.warm.opacity(0.35 * warmth), .clear]),
            center: CGPoint(x: size.width / 2, y: floor - unit * 0.18), startRadius: 0, endRadius: unit * 0.4
        ))
        // Interior and counter.
        graphics.fill(Path(CGRect(x: left, y: roof + unit * 0.06, width: width, height: unit * 0.2)), with: .color(Color(hex: 0xF2B66D).opacity(0.75 * warmth + 0.2)))
        graphics.fill(Path(CGRect(x: left - unit * 0.02, y: floor - unit * 0.12, width: width + unit * 0.04, height: unit * 0.03)), with: .color(Color(hex: 0x6B3E22)))
        graphics.fill(Path(CGRect(x: left, y: floor - unit * 0.09, width: width, height: unit * 0.09)), with: .color(Color(hex: 0x4A2A17)))
        graphics.fill(Path(CGRect(x: left - unit * 0.03, y: roof, width: width + unit * 0.06, height: unit * 0.06)), with: .color(Color(hex: 0x2A1A14)))

        // Noren curtain swaying with the melody.
        let strips = 5
        let stripWidth = width / CGFloat(strips)
        for index in 0..<strips {
            let swing = CGFloat(sin(phase * 1.3 + Double(index) * 0.8)) * unit * 0.012 * CGFloat(0.4 + Double(audio.mid))
            var strip = Path()
            let x = left + CGFloat(index) * stripWidth
            strip.addLines([CGPoint(x: x + unit * 0.003, y: roof + unit * 0.06), CGPoint(x: x + stripWidth - unit * 0.003, y: roof + unit * 0.06), CGPoint(x: x + stripWidth - unit * 0.003 + swing, y: roof + unit * 0.16), CGPoint(x: x + unit * 0.003 + swing, y: roof + unit * 0.16)])
            strip.closeSubpath()
            graphics.fill(strip, with: .color(TokyoTheme.lantern))
        }
        // A simple white emblem across the middle strips.
        graphics.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - unit * 0.025, y: roof + unit * 0.085, width: unit * 0.05, height: unit * 0.05)), with: .color(.white.opacity(0.85)), lineWidth: unit * 0.006)

        // Bowls with steam.
        for index in 0..<3 {
            let bowl = CGPoint(x: left + width * CGFloat(0.25 + 0.25 * Double(index)), y: floor - unit * 0.12)
            graphics.fill(Path(ellipseIn: CGRect(x: bowl.x - unit * 0.025, y: bowl.y - unit * 0.02, width: unit * 0.05, height: unit * 0.025)), with: .color(Color(hex: 0xEDE6DA)))
            var steam = Path()
            steam.move(to: bowl + CGPoint(x: 0, y: -unit * 0.02))
            for step in 1...14 {
                let t = Double(step) / 14
                steam.addLine(to: bowl + CGPoint(x: unit * 0.01 * CGFloat(sin(phase * 2 + t * 6 + Double(index))) * CGFloat(t), y: -unit * 0.02 - unit * 0.1 * CGFloat(t)))
            }
            graphics.stroke(steam, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)]),
                startPoint: bowl, endPoint: bowl + CGPoint(x: 0, y: -unit * 0.12)
            ), style: StrokeStyle(lineWidth: unit * 0.006, lineCap: .round))
        }
    }

    private func drawLanterns(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, phase: Double, frame: AudioFrame) {
        let audio = frame.audio
        let wireY = size.height * 0.08
        var wire = Path()
        wire.move(to: CGPoint(x: 0, y: wireY))
        wire.addQuadCurve(to: CGPoint(x: size.width, y: wireY), control: CGPoint(x: size.width / 2, y: wireY + unit * 0.08))
        graphics.stroke(wire, with: .color(Color(hex: 0x05060C)), lineWidth: max(1, unit * 0.003))
        var glow = graphics
        glow.blendMode = .plusLighter
        for index in 0..<5 {
            let t = CGFloat(0.15 + 0.175 * Double(index))
            let hang = CGPoint(x: size.width * t, y: wireY + unit * 0.08 * 2 * t * (1 - t) * 2)
            let angle = sin(phase + Double(index) * 1.1) * 0.12 * (0.4 + Double(audio.mid))
            let length = unit * 0.05
            let center = hang + CGPoint(x: sin(angle) * length, y: cos(angle) * length)
            let rx = unit * 0.035, ry = unit * 0.045
            let light = 0.5 + 0.5 * Double(audio.bass)
            glow.fill(Path(ellipseIn: CGRect(x: center.x - rx * 3, y: center.y - ry * 3, width: rx * 6, height: ry * 6)), with: .radialGradient(
                Gradient(colors: [TokyoTheme.lantern.opacity(0.35 * light), .clear]), center: center, startRadius: 0, endRadius: ry * 3
            ))
            var string = Path()
            string.addLines([hang, center])
            graphics.stroke(string, with: .color(Color(hex: 0x05060C)), lineWidth: max(1, unit * 0.002))
            graphics.fill(Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)), with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFF8A65).mix(with: .white, by: 0.3 * light), TokyoTheme.lantern]), center: center, startRadius: 0, endRadius: ry
            ))
            var ribs = Path()
            for rib in [-0.5, 0.0, 0.5] as [CGFloat] {
                ribs.move(to: CGPoint(x: center.x - rx * sqrt(1 - rib * rib), y: center.y + ry * rib))
                ribs.addLine(to: CGPoint(x: center.x + rx * sqrt(1 - rib * rib), y: center.y + ry * rib))
            }
            graphics.stroke(ribs, with: .color(.black.opacity(0.3)), lineWidth: max(1, unit * 0.002))
            graphics.fill(Path(CGRect(x: center.x - rx * 0.5, y: center.y - ry - unit * 0.006, width: rx, height: unit * 0.008)), with: .color(Color(hex: 0x1A1A1A)))
            graphics.fill(Path(CGRect(x: center.x - rx * 0.5, y: center.y + ry - unit * 0.002, width: rx, height: unit * 0.008)), with: .color(Color(hex: 0x1A1A1A)))
        }
    }

    private func drawVendingMachine(in graphics: inout GraphicsContext, rect: CGRect, unit: CGFloat, frame: AudioFrame) {
        var glow = graphics
        glow.blendMode = .plusLighter
        glow.fill(Path(ellipseIn: CGRect(x: rect.midX - unit * 0.25, y: rect.midY - unit * 0.25, width: unit * 0.5, height: unit * 0.5)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xBFE8FF).opacity(0.25), .clear]), center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: unit * 0.25
        ))
        graphics.fill(Path(roundedRect: rect, cornerRadius: unit * 0.008), with: .color(Color(hex: 0xE8EEF5)))
        let window = rect.insetBy(dx: unit * 0.012, dy: unit * 0.02).offsetBy(dx: 0, dy: -unit * 0.04)
        graphics.fill(Path(CGRect(x: window.minX, y: window.minY, width: window.width, height: window.height * 0.62)), with: .color(Color(hex: 0xF6FBFF)))
        let colors = [TokyoTheme.red, TokyoTheme.cyan, TokyoTheme.amber, Color(hex: 0x6BCB77), TokyoTheme.purple]
        for row in 0..<3 {
            for column in 0..<5 {
                let can = CGRect(x: window.minX + window.width * (0.06 + 0.19 * CGFloat(column)), y: window.minY + window.height * (0.05 + 0.2 * CGFloat(row)), width: window.width * 0.12, height: window.height * 0.15)
                graphics.fill(Path(roundedRect: can, cornerRadius: unit * 0.003), with: .color(colors[(row + column) % colors.count]))
            }
        }
        graphics.fill(Path(CGRect(x: rect.minX + unit * 0.03, y: rect.maxY - unit * 0.06, width: rect.width - unit * 0.06, height: unit * 0.03)), with: .color(Color(hex: 0x2A2F3A)))
    }

    private func drawCat(in graphics: inout GraphicsContext, base: CGPoint, unit: CGFloat, frame: AudioFrame) {
        let color = Color(hex: 0x05060C)
        var crate = Path(CGRect(x: base.x - unit * 0.07, y: base.y - unit * 0.08, width: unit * 0.14, height: unit * 0.08))
        crate.addRect(CGRect(x: base.x - unit * 0.07, y: base.y - unit * 0.045, width: unit * 0.14, height: unit * 0.006))
        graphics.fill(crate, with: .color(Color(hex: 0x2A2234)))
        let seat = base + CGPoint(x: 0, y: -unit * 0.08)
        let flick = Double(frame.audio.beatPulse)
        var tail = Path()
        tail.move(to: seat + CGPoint(x: unit * 0.03, y: -unit * 0.01))
        tail.addQuadCurve(to: seat + CGPoint(x: unit * (0.08 + 0.02 * CGFloat(flick)), y: -unit * (0.03 + 0.06 * CGFloat(flick))), control: seat + CGPoint(x: unit * 0.08, y: 0))
        graphics.stroke(tail, with: .color(color), style: StrokeStyle(lineWidth: unit * 0.01, lineCap: .round))
        graphics.fill(Path(ellipseIn: CGRect(x: seat.x - unit * 0.035, y: seat.y - unit * 0.08, width: unit * 0.07, height: unit * 0.08)), with: .color(color))
        let head = seat + CGPoint(x: -unit * 0.005, y: -unit * 0.095)
        var cat = Path(ellipseIn: CGRect(x: head.x - unit * 0.025, y: head.y - unit * 0.022, width: unit * 0.05, height: unit * 0.044))
        for side: CGFloat in [-1, 1] {
            cat.addLines([head + CGPoint(x: side * unit * 0.022, y: -unit * 0.008), head + CGPoint(x: side * unit * 0.02, y: -unit * 0.04), head + CGPoint(x: side * unit * 0.005, y: -unit * 0.02)])
            cat.closeSubpath()
        }
        graphics.fill(cat, with: .color(color))
        // Eyes catch the neon.
        for side: CGFloat in [-1, 1] {
            graphics.fill(Path(ellipseIn: CGRect(x: head.x + side * unit * 0.01 - unit * 0.004, y: head.y - unit * 0.004, width: unit * 0.008, height: unit * 0.006)), with: .color(Color(hex: 0xC6FF6B)))
        }
    }
}
