//
//  LateNightDeskWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct LateNightDeskWallpaper: View {
    let context: WallpaperContext
    @State private var steam = PhaseClock()
    @State private var leaves = PhaseClock()

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
        let deskY = size.height * 0.7
        let lampLevel = 0.25 + 0.4 * Double(audio.level)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [LofiTheme.wall, LofiTheme.wallDark]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: deskY)
        ))

        drawWindow(in: &graphics, rect: CGRect(x: size.width * 0.5, y: size.height * 0.1, width: size.width * 0.38, height: size.height * 0.46), unit: unit, frame: frame)

        // Warm lamp light washing over the wall.
        let lampHead = CGPoint(x: size.width * 0.2, y: deskY - unit * 0.3)
        LofiTheme.glow(in: graphics, at: lampHead + CGPoint(x: unit * 0.06, y: unit * 0.1), radius: unit * 0.55, color: LofiTheme.lamp, opacity: lampLevel)

        // Desk.
        graphics.fill(Path(CGRect(x: 0, y: deskY, width: size.width, height: unit * 0.035)), with: .color(LofiTheme.wood))
        graphics.fill(Path(CGRect(x: 0, y: deskY + unit * 0.035, width: size.width, height: size.height)), with: .color(LofiTheme.woodDark))
        LofiTheme.glow(in: graphics, at: CGPoint(x: lampHead.x + unit * 0.08, y: deskY), radius: unit * 0.3, color: LofiTheme.lamp, opacity: lampLevel * 0.8)

        // Lamp.
        let lampBase = CGPoint(x: size.width * 0.16, y: deskY)
        graphics.fill(LofiTheme.ellipse(lampBase, unit * 0.06, unit * 0.014), with: .color(LofiTheme.ink))
        var arm = Path()
        arm.addLines([lampBase, lampBase + CGPoint(x: -unit * 0.03, y: -unit * 0.2), lampHead])
        graphics.stroke(arm, with: .color(LofiTheme.ink), style: StrokeStyle(lineWidth: unit * 0.012, lineCap: .round, lineJoin: .round))
        var cone = Path()
        cone.addLines([lampHead + CGPoint(x: -unit * 0.02, y: unit * 0.02), lampHead + CGPoint(x: unit * 0.06, y: -unit * 0.035), CGPoint(x: lampHead.x + unit * 0.35, y: deskY), CGPoint(x: lampHead.x - unit * 0.05, y: deskY)])
        cone.closeSubpath()
        graphics.fill(cone, with: .linearGradient(
            Gradient(colors: [LofiTheme.lamp.opacity(lampLevel * 0.6), LofiTheme.lamp.opacity(0)]),
            startPoint: lampHead, endPoint: CGPoint(x: lampHead.x + unit * 0.1, y: deskY)
        ))
        var shade = Path()
        shade.addLines([lampHead + CGPoint(x: -unit * 0.05, y: -unit * 0.02), lampHead + CGPoint(x: unit * 0.03, y: -unit * 0.07), lampHead + CGPoint(x: unit * 0.09, y: unit * 0.0), lampHead + CGPoint(x: -unit * 0.01, y: unit * 0.04)])
        shade.closeSubpath()
        graphics.fill(shade, with: .color(LofiTheme.clay))
        LofiTheme.glow(in: graphics, at: lampHead + CGPoint(x: unit * 0.03, y: unit * 0.02), radius: unit * 0.03, color: LofiTheme.cream, opacity: 0.8)

        // Books.
        let books: [(CGFloat, CGFloat, Color)] = [(0.12, 0.022, LofiTheme.pink), (0.11, 0.018, LofiTheme.cream), (0.13, 0.024, LofiTheme.teal)]
        var bookY = deskY
        for (width, height, color) in books {
            bookY -= unit * height
            graphics.fill(Path(roundedRect: CGRect(x: size.width * 0.3, y: bookY, width: unit * width, height: unit * height), cornerRadius: unit * 0.003), with: .color(color))
        }

        // Mug with steam curling up.
        let mug = CGRect(x: size.width * 0.42, y: deskY - unit * 0.07, width: unit * 0.055, height: unit * 0.07)
        graphics.stroke(LofiTheme.ellipse(CGPoint(x: mug.maxX, y: mug.midY), unit * 0.016, unit * 0.018), with: .color(LofiTheme.cream), lineWidth: unit * 0.008)
        graphics.fill(Path(roundedRect: mug, cornerRadius: unit * 0.01), with: .color(LofiTheme.cream))
        let rise = steam.advance(to: frame.time, speed: 0.5 + 0.6 * Double(audio.mid))
        for wisp in 0..<3 {
            var path = Path()
            let startX = mug.minX + mug.width * CGFloat(0.25 + 0.25 * Double(wisp))
            let offset = Double(wisp) * 2.1
            path.move(to: CGPoint(x: startX, y: mug.minY - unit * 0.01))
            for step in 1...20 {
                let t = Double(step) / 20
                path.addLine(to: CGPoint(
                    x: startX + unit * 0.012 * CGFloat(sin(rise * 3 + t * 7 + offset)) * CGFloat(t),
                    y: mug.minY - unit * 0.01 - unit * 0.14 * CGFloat(t)
                ))
            }
            graphics.stroke(path, with: .linearGradient(
                Gradient(colors: [LofiTheme.cream.opacity(0.45), LofiTheme.cream.opacity(0)]),
                startPoint: CGPoint(x: startX, y: mug.minY), endPoint: CGPoint(x: startX, y: mug.minY - unit * 0.15)
            ), style: StrokeStyle(lineWidth: unit * 0.005, lineCap: .round))
        }

        // Plant swaying with the melody.
        let sway = leaves.advance(to: frame.time, speed: 1 + Double(audio.mid))
        let pot = CGRect(x: size.width * 0.9 - unit * 0.04, y: deskY - unit * 0.07, width: unit * 0.08, height: unit * 0.07)
        let stem = CGPoint(x: pot.midX, y: pot.minY)
        for index in 0..<7 {
            let angle = -.pi / 2 + (Double(index) - 3) * 0.33 + sin(sway + Double(index)) * 0.06 * (0.5 + Double(audio.mid))
            let length = unit * CGFloat(0.09 + 0.03 * hash01(index, 4))
            graphics.fill(LofiTheme.leaf(from: stem, angle: angle, length: length, width: unit * 0.022), with: .color(index % 2 == 0 ? LofiTheme.plant : LofiTheme.plantDark))
        }
        var potShape = Path()
        potShape.addLines([CGPoint(x: pot.minX, y: pot.minY), CGPoint(x: pot.maxX, y: pot.minY), CGPoint(x: pot.maxX - unit * 0.01, y: pot.maxY), CGPoint(x: pot.minX + unit * 0.01, y: pot.maxY)])
        potShape.closeSubpath()
        graphics.fill(potShape, with: .color(LofiTheme.clay))

        drawCat(in: &graphics, base: CGPoint(x: size.width * 0.66, y: deskY), unit: unit, frame: frame)
    }

    private func drawWindow(in graphics: inout GraphicsContext, rect: CGRect, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let frameWidth = unit * 0.02
        graphics.fill(Path(roundedRect: rect.insetBy(dx: -frameWidth, dy: -frameWidth), cornerRadius: unit * 0.008), with: .color(Color(hex: 0x262241)))

        var view = graphics
        view.clip(to: Path(rect))
        view.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [LofiTheme.nightSky, Color(hex: 0x3B4A7A)]),
            startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)
        ))
        let moon = CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.22)
        LofiTheme.glow(in: view, at: moon, radius: unit * 0.08, color: LofiTheme.cream, opacity: 0.3)
        view.fill(LofiTheme.ellipse(moon, unit * 0.03, unit * 0.03), with: .color(LofiTheme.cream))

        var buildings = Path()
        var windows = Path()
        var x = rect.minX
        var index = 0
        while x < rect.maxX {
            let width = unit * CGFloat(0.05 + 0.04 * hash01(index, 1))
            let height = rect.height * CGFloat(0.2 + 0.35 * hash01(index, 2))
            buildings.addRect(CGRect(x: x, y: rect.maxY - height, width: width, height: height))
            for row in 0..<Int(height / (unit * 0.025)) {
                for column in 0..<2 where hash01(index * 5 + column, row) > 0.6 {
                    windows.addRect(CGRect(x: x + width * (0.2 + 0.4 * CGFloat(column)), y: rect.maxY - height + unit * 0.012 + CGFloat(row) * unit * 0.025, width: width * 0.2, height: unit * 0.01))
                }
            }
            x += width + unit * 0.006
            index += 1
        }
        view.fill(buildings, with: .color(Color(hex: 0x161A35)))
        view.fill(windows, with: .color(LofiTheme.lamp.opacity(0.75)))

        // Rain on the other side of the glass.
        var rain = Path()
        let drops = 30 + Int(80 * Double(audio.level))
        for drop in 0..<drops {
            let fall = (hash01(drop, 7) + frame.time * (0.7 + 0.5 * hash01(drop, 8))).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: rect.minX + CGFloat(hash01(drop, 9)) * rect.width, y: rect.minY + CGFloat(fall) * rect.height * 1.1)
            rain.move(to: point)
            rain.addLine(to: point + CGPoint(x: -unit * 0.003, y: -unit * 0.025))
        }
        view.stroke(rain, with: .color(.white.opacity(0.18)), lineWidth: max(1, unit * 0.0015))

        var bars = Path()
        bars.addRect(CGRect(x: rect.midX - frameWidth * 0.3, y: rect.minY, width: frameWidth * 0.6, height: rect.height))
        bars.addRect(CGRect(x: rect.minX, y: rect.midY - frameWidth * 0.3, width: rect.width, height: frameWidth * 0.6))
        graphics.fill(bars, with: .color(Color(hex: 0x262241)))
        graphics.fill(Path(CGRect(x: rect.minX - frameWidth * 2, y: rect.maxY + frameWidth, width: rect.width + frameWidth * 4, height: frameWidth * 0.8)), with: .color(Color(hex: 0x262241)))
    }

    /// A cat watching the rain, tail tapping on the beat.
    private func drawCat(in graphics: inout GraphicsContext, base: CGPoint, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let color = LofiTheme.ink
        let body = base + CGPoint(x: 0, y: -unit * 0.07)
        let tap = Double(audio.beatPulse)
        let tailAngle = -0.2 - 0.9 * tap
        var tail = Path()
        let tailStart = base + CGPoint(x: unit * 0.05, y: -unit * 0.012)
        let tailEnd = tailStart + CGPoint(x: cos(tailAngle) * unit * 0.11, y: sin(tailAngle) * unit * 0.11)
        tail.move(to: tailStart)
        tail.addQuadCurve(to: tailEnd, control: tailStart + CGPoint(x: unit * 0.07, y: unit * 0.01))
        graphics.stroke(tail, with: .color(color), style: StrokeStyle(lineWidth: unit * 0.016, lineCap: .round))

        graphics.fill(LofiTheme.ellipse(body, unit * 0.062, unit * 0.072), with: .color(color))
        let head = body + CGPoint(x: 0, y: -unit * 0.085)
        graphics.fill(LofiTheme.ellipse(head, unit * 0.042, unit * 0.038), with: .color(color))
        var ears = Path()
        for side: CGFloat in [-1, 1] {
            ears.move(to: head + CGPoint(x: side * unit * 0.038, y: -unit * 0.012))
            ears.addLine(to: head + CGPoint(x: side * unit * 0.034, y: -unit * 0.062))
            ears.addLine(to: head + CGPoint(x: side * unit * 0.008, y: -unit * 0.032))
            ears.closeSubpath()
        }
        graphics.fill(ears, with: .color(color))
    }
}
