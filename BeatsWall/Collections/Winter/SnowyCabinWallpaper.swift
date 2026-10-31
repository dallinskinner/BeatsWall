//
//  SnowyCabinWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct SnowyCabinWallpaper: View {
    let context: WallpaperContext
    @State private var smoke = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(WinterTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let ground = size.height * 0.74
        let drift = smoke.advance(to: frame.time, speed: 0.5 + Double(audio.mid))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [WinterTheme.night, WinterTheme.deep, WinterTheme.dusk]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: ground)
        ))
        var stars = Path()
        for index in 0..<70 {
            stars.addPath(WinterTheme.disc(CGPoint(x: CGFloat(hash01(index, 1)) * size.width, y: CGFloat(hash01(index, 2)) * ground * 0.5), unit * 0.0015 * CGFloat(0.6 + hash01(index, 3))))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.7)))
        let moon = CGPoint(x: size.width * 0.82, y: size.height * 0.16)
        WinterTheme.glow(in: graphics, at: moon, radius: unit * 0.2, color: WinterTheme.snow, opacity: 0.18)
        graphics.fill(WinterTheme.disc(moon, unit * 0.045), with: .color(WinterTheme.snow))

        // Snowy hills.
        for (layer, (base, amplitude, color)) in [(ground - unit * 0.08, 0.05, WinterTheme.snowShade.opacity(0.55)), (ground, 0.03, WinterTheme.snowShade)].enumerated() {
            var hill = Path()
            hill.move(to: CGPoint(x: 0, y: size.height))
            var x: CGFloat = 0
            while x <= size.width + 6 {
                let s = Double(x / unit)
                hill.addLine(to: CGPoint(x: x, y: base - unit * CGFloat(amplitude * (1 + sin(s * 2.1 + Double(layer) * 2)))))
                x += 6
            }
            hill.addLine(to: CGPoint(x: size.width + 6, y: size.height))
            hill.closeSubpath()
            graphics.fill(hill, with: .color(color))
        }

        // Pines around the cabin.
        let pines: [(CGFloat, CGFloat, CGFloat)] = [(0.08, 0.36, 0.0), (0.18, 0.26, 0.02), (0.72, 0.3, 0.01), (0.86, 0.42, 0.0), (0.95, 0.28, 0.02), (0.6, 0.18, -0.02)]
        for (x, height, lift) in pines {
            let (tree, snow) = WinterTheme.pinePath(base: CGPoint(x: size.width * x, y: ground - unit * lift), height: unit * height)
            graphics.fill(tree, with: .color(WinterTheme.pineDark))
            graphics.fill(snow, with: .color(WinterTheme.snow.opacity(0.9)))
        }

        drawCabin(in: &graphics, size: size, unit: unit, ground: ground, drift: drift, frame: frame)

        // Foreground snow bank.
        var bank = Path()
        bank.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 6 {
            bank.addLine(to: CGPoint(x: x, y: size.height * 0.9 - unit * 0.02 * CGFloat(sin(Double(x / unit) * 3))))
            x += 6
        }
        bank.addLine(to: CGPoint(x: size.width + 6, y: size.height))
        bank.closeSubpath()
        graphics.fill(bank, with: .color(WinterTheme.snow))

        WinterTheme.drawSnowfall(in: &graphics, size: size, time: frame.time, density: Double(audio.level), maxFlakes: context.isReduced ? 150 : 400)
    }

    private func drawCabin(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, ground: CGFloat, drift: Double, frame: AudioFrame) {
        let audio = frame.audio
        let width = unit * 0.42
        let wallHeight = unit * 0.18
        let left = size.width * 0.42 - width / 2
        let wallTop = ground - wallHeight
        let warmth = 0.45 + 0.55 * Double(audio.level)

        // Light spilling onto the snow.
        var glow = graphics
        glow.blendMode = .plusLighter
        WinterTheme.glow(in: glow, at: CGPoint(x: left + width / 2, y: ground), radius: unit * 0.35, color: WinterTheme.warm, opacity: 0.25 * warmth)

        // Chimney and smoke.
        let chimney = CGRect(x: left + width * 0.7, y: wallTop - unit * 0.17, width: unit * 0.045, height: unit * 0.12)
        graphics.fill(Path(chimney), with: .color(Color(hex: 0x5A4A48)))
        for puff in 0..<6 {
            let t = (drift * 0.15 + Double(puff) / 6).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: chimney.midX + unit * 0.05 * CGFloat(sin(t * 5 + drift * 0.3)) + unit * 0.08 * CGFloat(t), y: chimney.minY - unit * 0.25 * CGFloat(t))
            graphics.fill(WinterTheme.disc(point, unit * CGFloat(0.012 + 0.03 * t)), with: .color(WinterTheme.snowShade.opacity(0.35 * (1 - t))))
        }

        // Log walls.
        let walls = CGRect(x: left, y: wallTop, width: width, height: wallHeight)
        graphics.fill(Path(walls), with: .color(WinterTheme.wood))
        var logs = Path()
        var y = wallTop + unit * 0.02
        while y < ground {
            logs.addRect(CGRect(x: left, y: y, width: width, height: max(1, unit * 0.003)))
            y += unit * 0.025
        }
        graphics.fill(logs, with: .color(WinterTheme.woodDark))

        // Windows and door.
        for wx in [0.14, 0.66] as [CGFloat] {
            let window = CGRect(x: left + width * wx, y: wallTop + wallHeight * 0.25, width: width * 0.2, height: wallHeight * 0.38)
            graphics.fill(Path(window), with: .color(WinterTheme.warm.mix(with: .black, by: 0.5 - 0.45 * warmth)))
            WinterTheme.glow(in: glow, at: CGPoint(x: window.midX, y: window.midY), radius: window.width, color: WinterTheme.warm, opacity: 0.3 * warmth)
            var bars = Path()
            bars.addRect(CGRect(x: window.midX - unit * 0.002, y: window.minY, width: unit * 0.004, height: window.height))
            bars.addRect(CGRect(x: window.minX, y: window.midY - unit * 0.002, width: window.width, height: unit * 0.004))
            graphics.fill(bars, with: .color(WinterTheme.woodDark))
            graphics.fill(Path(roundedRect: CGRect(x: window.minX - unit * 0.004, y: window.maxY - unit * 0.004, width: window.width + unit * 0.008, height: unit * 0.012), cornerRadius: unit * 0.006), with: .color(WinterTheme.snow))
        }
        let door = CGRect(x: left + width * 0.42, y: wallTop + wallHeight * 0.3, width: width * 0.16, height: wallHeight * 0.7)
        graphics.fill(Path(door), with: .color(WinterTheme.woodDark))
        // A wreath on the door.
        let wreath = CGPoint(x: door.midX, y: door.minY + door.height * 0.3)
        graphics.stroke(WinterTheme.disc(wreath, unit * 0.014), with: .color(WinterTheme.pine), lineWidth: unit * 0.007)
        graphics.fill(WinterTheme.disc(wreath + CGPoint(x: 0, y: unit * 0.014), unit * 0.004), with: .color(WinterTheme.red))

        // Roof with a thick blanket of snow.
        let eave = unit * 0.035
        let peak = CGPoint(x: left + width / 2, y: wallTop - unit * 0.15)
        var roof = Path()
        roof.addLines([CGPoint(x: left - eave, y: wallTop + unit * 0.01), peak, CGPoint(x: left + width + eave, y: wallTop + unit * 0.01)])
        roof.closeSubpath()
        graphics.fill(roof, with: .color(Color(hex: 0x3A2A28)))
        var snowRoof = Path()
        snowRoof.move(to: CGPoint(x: left - eave * 1.4, y: wallTop + unit * 0.005))
        snowRoof.addLine(to: peak + CGPoint(x: 0, y: -unit * 0.02))
        snowRoof.addLine(to: CGPoint(x: left + width + eave * 1.4, y: wallTop + unit * 0.005))
        for step in stride(from: 10, through: 0, by: -1) {
            let t = CGFloat(step) / 10
            let x = left - eave * 1.4 + (width + eave * 2.8) * t
            snowRoof.addQuadCurve(to: CGPoint(x: x, y: wallTop + unit * 0.012), control: CGPoint(x: x + unit * 0.015, y: wallTop + unit * 0.03))
        }
        snowRoof.closeSubpath()
        graphics.fill(snowRoof, with: .color(WinterTheme.snow))

        // String lights along the eaves, blinking in patterns that change every bar.
        let bulbs = 18
        var bulbPositions: [CGPoint] = []
        for index in 0..<bulbs {
            let t = CGFloat(index) / CGFloat(bulbs - 1)
            let x = left - eave + (width + eave * 2) * t
            let sag = unit * 0.012 * sin(.pi * (t * CGFloat(bulbs - 1)).truncatingRemainder(dividingBy: 1))
            bulbPositions.append(CGPoint(x: x, y: wallTop + unit * 0.03 + sag))
        }
        var wire = Path()
        wire.addLines(bulbPositions)
        graphics.stroke(wire, with: .color(Color(hex: 0x1A2A1F)), lineWidth: max(1, unit * 0.002))
        for (index, point) in bulbPositions.enumerated() {
            let color = WinterTheme.bulbColors[index % WinterTheme.bulbColors.count]
            let lit = WinterTheme.bulbLit(index, beat: audio.beatCount)
            let brightness = lit ? 0.6 + 0.4 * Double(audio.bass) : 0.12
            WinterTheme.glow(in: glow, at: point, radius: unit * 0.025, color: color, opacity: 0.6 * brightness)
            graphics.fill(Path(ellipseIn: CGRect(x: point.x - unit * 0.004, y: point.y - unit * 0.002, width: unit * 0.008, height: unit * 0.012)), with: .color(color.mix(with: .white, by: 0.35 * brightness).opacity(0.35 + 0.65 * brightness)))
        }
    }
}
