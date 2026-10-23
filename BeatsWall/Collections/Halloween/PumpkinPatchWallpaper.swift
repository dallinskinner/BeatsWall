//
//  PumpkinPatchWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct PumpkinPatchWallpaper: View {
    let context: WallpaperContext
    @State private var fog = PhaseClock()

    /// Far to near: position (fractions of the screen), size (fraction of unit) and which band it sings.
    private static let pumpkins: [(x: CGFloat, y: CGFloat, size: CGFloat, band: Int)] = [
        (0.52, 0.7, 0.07, 2), (0.2, 0.77, 0.12, 0), (0.66, 0.8, 0.11, 3), (0.4, 0.87, 0.16, 1), (0.84, 0.89, 0.15, 4),
    ]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(HalloweenTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.6
        let drift = fog.advance(to: frame.time, speed: 0.02 + 0.03 * Double(audio.mid))

        HalloweenTheme.sky(in: &graphics, size: size, horizon: horizon, low: Color(hex: 0x4A3048))
        let moon = CGPoint(x: size.width * 0.8, y: size.height * 0.2)
        HalloweenTheme.drawMoon(in: &graphics, center: moon, radius: unit * 0.07, brightness: 0.4)
        for index in 0..<4 {
            let span = size.width + unit
            let raw = CGFloat(hash01(index, 5)) * span + CGFloat(drift) * unit * 0.6
            let x = raw - (raw / span).rounded(.down) * span - unit * 0.5
            graphics.fill(HalloweenTheme.ellipse(CGPoint(x: x, y: size.height * CGFloat(0.14 + 0.08 * Double(index))), unit * 0.25, unit * 0.022), with: .color(HalloweenTheme.purple.opacity(0.7)))
        }

        // Tree line, fence and field.
        var trees = Path()
        trees.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 5 {
            let s = Double(x / unit)
            let crown = abs(sin(s * 9)) * 0.03 + abs(sin(s * 23 + 1)) * 0.015
            trees.addLine(to: CGPoint(x: x, y: horizon - unit * CGFloat(0.04 + crown)))
            x += 5
        }
        trees.addLine(to: CGPoint(x: size.width + 5, y: size.height))
        trees.closeSubpath()
        graphics.fill(trees, with: .color(Color(hex: 0x15121F)))
        var fence = Path()
        var post: CGFloat = unit * 0.02
        while post < size.width {
            let lean = CGFloat(hash01(Int(post), 7) - 0.5) * unit * 0.012
            fence.addLines([CGPoint(x: post, y: horizon + unit * 0.02), CGPoint(x: post + lean, y: horizon - unit * 0.035)])
            post += unit * 0.07
        }
        fence.move(to: CGPoint(x: 0, y: horizon - unit * 0.015))
        fence.addLine(to: CGPoint(x: size.width, y: horizon - unit * 0.012))
        graphics.stroke(fence, with: .color(HalloweenTheme.silhouette), lineWidth: unit * 0.005)
        graphics.fill(Path(CGRect(x: 0, y: horizon + unit * 0.01, width: size.width, height: size.height)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x120F18), HalloweenTheme.silhouette]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Curling vines linking the pumpkins.
        var vines = Path()
        for index in 0..<(Self.pumpkins.count - 1) {
            let a = Self.pumpkins[index], b = Self.pumpkins[index + 1]
            let start = CGPoint(x: size.width * a.x, y: size.height * a.y)
            let end = CGPoint(x: size.width * b.x, y: size.height * b.y)
            vines.move(to: start)
            for step in 1...24 {
                let t = CGFloat(step) / 24
                let point = start + (end - start) * t
                vines.addLine(to: point + CGPoint(x: 0, y: unit * 0.02 * CGFloat(sin(Double(t) * 14 + Double(index)))))
            }
        }
        graphics.stroke(vines, with: .color(Color(hex: 0x0E1610)), style: StrokeStyle(lineWidth: unit * 0.004, lineCap: .round))

        for (index, pumpkin) in Self.pumpkins.enumerated() {
            drawPumpkin(in: &graphics, center: CGPoint(x: size.width * pumpkin.x, y: size.height * pumpkin.y), radius: unit * pumpkin.size, band: pumpkin.band, seed: index, frame: frame)
        }

        HalloweenTheme.drawFog(in: &graphics, size: size, top: horizon, drift: drift, density: 0.6, tint: Color(hex: 0x9A8FA8), banks: 12)
    }

    private func drawPumpkin(in graphics: inout GraphicsContext, center: CGPoint, radius: CGFloat, band: Int, seed: Int, frame: AudioFrame) {
        let audio = frame.audio
        // Candlelight flickers on its own, swells with the bass.
        let flicker = 0.8 + 0.2 * sin(frame.time * 13 + Double(seed) * 2) * sin(frame.time * 7.3 + Double(seed))
        let light = min(1, flicker * (0.5 + 0.5 * Double(audio.bass)))
        // Each pumpkin sings its own slice of the spectrum.
        let bins = AudioFeatures.binCount / 5
        let voice = audio.spectrum[(band * bins)..<((band + 1) * bins)].reduce(0, +) / Float(bins)
        let open = 0.25 + 0.75 * Double(voice)

        var lit = graphics
        lit.blendMode = .plusLighter
        // Light spilling onto the ground.
        var spill = lit
        spill.translateBy(x: center.x, y: center.y + radius * 0.8)
        spill.scaleBy(x: 1, y: 0.28)
        HalloweenTheme.glow(in: spill, at: .zero, radius: radius * 2.4, color: HalloweenTheme.pumpkin, opacity: 0.3 * light)

        // Ribbed body, dark but warmed from inside.
        var body = Path()
        for (dx, rx) in [(-0.55, 0.55), (0.55, 0.55), (-0.25, 0.6), (0.25, 0.6), (0.0, 0.55)] as [(CGFloat, CGFloat)] {
            body.addPath(HalloweenTheme.ellipse(center + CGPoint(x: dx * radius, y: 0), rx * radius, radius * 0.82))
        }
        graphics.fill(body, with: .color(Color(hex: 0x2A1408)))
        var warmth = graphics
        warmth.clip(to: body)
        warmth.fill(body, with: .radialGradient(
            Gradient(colors: [HalloweenTheme.pumpkin.opacity(0.45 * light), Color(hex: 0x2A1408).opacity(0)]),
            center: center + CGPoint(x: 0, y: radius * 0.1), startRadius: 0, endRadius: radius * 1.3
        ))
        var ribs = Path()
        for dx: CGFloat in [-0.42, 0, 0.42] {
            ribs.addPath(HalloweenTheme.ellipse(center + CGPoint(x: dx * radius, y: 0), radius * 0.3, radius * 0.8))
        }
        warmth.stroke(ribs, with: .color(.black.opacity(0.35)), lineWidth: radius * 0.03)
        var stem = Path()
        stem.move(to: center + CGPoint(x: -radius * 0.06, y: -radius * 0.75))
        stem.addQuadCurve(to: center + CGPoint(x: radius * 0.12, y: -radius * 1.05), control: center + CGPoint(x: -radius * 0.05, y: -radius * 0.95))
        graphics.stroke(stem, with: .color(Color(hex: 0x14100A)), style: StrokeStyle(lineWidth: radius * 0.12, lineCap: .round))

        // Carved face: only the cut-outs glow.
        var face = Path()
        for side: CGFloat in [-1, 1] {
            face.addLines([
                center + CGPoint(x: side * radius * 0.5, y: -radius * 0.08),
                center + CGPoint(x: side * radius * 0.3, y: -radius * 0.42),
                center + CGPoint(x: side * radius * 0.12, y: -radius * 0.08),
            ])
            face.closeSubpath()
        }
        face.addLines([center + CGPoint(x: -radius * 0.07, y: radius * 0.08), center + CGPoint(x: 0, y: -radius * 0.04), center + CGPoint(x: radius * 0.07, y: radius * 0.08)])
        face.closeSubpath()
        let mouthTop = center.y + radius * 0.2
        let mouthDepth = radius * CGFloat(0.12 + 0.32 * open)
        var mouth: [CGPoint] = []
        let teeth = 6
        for index in 0...teeth {
            let t = CGFloat(index) / CGFloat(teeth)
            let x = center.x + radius * (-0.6 + 1.2 * t)
            let curve = -radius * 0.12 * (1 - pow(2 * t - 1, 2))
            mouth.append(CGPoint(x: x, y: mouthTop + curve + (index % 2 == 1 ? radius * 0.08 : 0)))
        }
        for index in stride(from: teeth, through: 0, by: -1) {
            let t = CGFloat(index) / CGFloat(teeth)
            let x = center.x + radius * (-0.6 + 1.2 * t)
            let curve = -radius * 0.12 * (1 - pow(2 * t - 1, 2))
            mouth.append(CGPoint(x: x, y: mouthTop + curve + mouthDepth * (1 - pow(2 * t - 1, 2)) + radius * 0.04))
        }
        face.addLines(mouth)
        face.closeSubpath()
        graphics.fill(face, with: .radialGradient(
            Gradient(colors: [HalloweenTheme.candle.mix(with: .white, by: 0.3 * light), HalloweenTheme.pumpkin]),
            center: center, startRadius: 0, endRadius: radius * 0.8
        ))
        graphics.fill(face, with: .color(.black.opacity(0.75 * (1 - light))))
        HalloweenTheme.glow(in: lit, at: center, radius: radius * 1.6, color: HalloweenTheme.pumpkin, opacity: 0.25 * light)
    }
}
