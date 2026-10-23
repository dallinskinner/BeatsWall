//
//  AbyssLureWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct AbyssLureWallpaper: View {
    let context: WallpaperContext

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DeepSeaTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x010307)))

        // The fish drifts slowly closer and away.
        let approach = 0.5 + 0.5 * sin(frame.time * 0.06)
        let scale = unit * CGFloat(0.55 + 0.2 * approach)
        let center = CGPoint(
            x: size.width * CGFloat(0.42 + 0.06 * sin(frame.time * 0.09)),
            y: size.height * 0.55 + unit * 0.02 * CGFloat(sin(frame.time * 0.4))
        )
        // Lure: dangles ahead on a curved rod, glowing with the bass.
        let rodBase = center + CGPoint(x: scale * 0.12, y: -scale * 0.32)
        let sway = CGFloat(sin(frame.time * 0.9)) * scale * 0.03
        let lure = center + CGPoint(x: scale * 0.52 + sway, y: -scale * 0.38 + CGFloat(sin(frame.time * 1.3)) * scale * 0.02)
        let flicker = 0.9 + 0.1 * sin(frame.time * 17)
        let glow = min(1, (0.35 + 0.65 * Double(audio.bass)) * flicker)

        // Far-off creatures blinking in the dark.
        var light = graphics
        light.blendMode = .plusLighter
        for index in 0..<10 {
            let blink = pow(max(0, sin(frame.time * (0.4 + hash01(index, 1)) + Double(index) * 3)), 8)
            let point = CGPoint(x: CGFloat(hash01(index, 2)) * size.width, y: CGFloat(hash01(index, 3)) * size.height)
            DeepSeaTheme.glow(in: light, at: point, radius: unit * 0.012, color: index % 2 == 0 ? DeepSeaTheme.cyan : DeepSeaTheme.pink, opacity: 0.6 * blink)
        }

        // The lure's light: everything nearby is lit by it.
        DeepSeaTheme.glow(in: light, at: lure, radius: unit * CGFloat(0.35 + 0.25 * glow), color: DeepSeaTheme.lure, opacity: 0.18 * glow)

        drawAngler(in: &graphics, center: center, scale: scale, lure: lure, glow: glow, frame: frame)

        var rod = Path()
        rod.move(to: rodBase)
        rod.addQuadCurve(to: lure, control: rodBase + CGPoint(x: scale * 0.15, y: -scale * 0.28))
        graphics.stroke(rod, with: .color(Color(hex: 0x1C2A33)), style: StrokeStyle(lineWidth: scale * 0.012, lineCap: .round))
        DeepSeaTheme.glow(in: light, at: lure, radius: scale * 0.08, color: DeepSeaTheme.lure, opacity: 0.8 * glow)
        light.fill(DeepSeaTheme.disc(lure, scale * 0.022), with: .color(DeepSeaTheme.lure.mix(with: .white, by: 0.5).opacity(0.5 + 0.5 * glow)))

        // Plankton glinting in the light, more with the hi-hats.
        var plankton = Path()
        for index in 0..<(context.isPreview ? 80 : 220) {
            let drift = frame.time * (0.01 + 0.02 * hash01(index, 31))
            let x = (hash01(index, 32) + drift).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: CGFloat(x) * size.width, y: CGFloat(hash01(index, 33)) * size.height)
            let distance = (point - lure).length / unit
            let lit = max(0, 1 - Double(distance) / 0.5)
            let twinkle = hash01(index, Int(frame.time * 5)) < 0.2 + 0.6 * Double(audio.treble) ? 1.0 : 0.3
            if lit * twinkle > 0.08 {
                plankton.addPath(DeepSeaTheme.disc(point, unit * 0.0018 * CGFloat(0.6 + lit)))
            }
        }
        light.fill(plankton, with: .color(DeepSeaTheme.lure.opacity(0.8)))
    }

    private func drawAngler(in graphics: inout GraphicsContext, center: CGPoint, scale: CGFloat, lure: CGPoint, glow: Double, frame: AudioFrame) {
        // Big round head, gaping jaw, small tapering body.
        var body = Path()
        body.move(to: center + CGPoint(x: scale * 0.32, y: -scale * 0.12))
        body.addCurve(to: center + CGPoint(x: -scale * 0.42, y: -scale * 0.05), control1: center + CGPoint(x: scale * 0.25, y: -scale * 0.45), control2: center + CGPoint(x: -scale * 0.25, y: -scale * 0.38))
        body.addLine(to: center + CGPoint(x: -scale * 0.62, y: -scale * 0.16))
        body.addLine(to: center + CGPoint(x: -scale * 0.6, y: scale * 0.14))
        body.addLine(to: center + CGPoint(x: -scale * 0.42, y: scale * 0.06))
        body.addCurve(to: center + CGPoint(x: scale * 0.36, y: scale * 0.16), control1: center + CGPoint(x: -scale * 0.25, y: scale * 0.32), control2: center + CGPoint(x: scale * 0.2, y: scale * 0.32))
        // Jaw opens a little with the music.
        let gape = scale * CGFloat(0.06 + 0.05 * Double(frame.audio.level))
        body.addLine(to: center + CGPoint(x: scale * 0.18, y: scale * 0.02 + gape))
        body.addLine(to: center + CGPoint(x: scale * 0.34, y: -scale * 0.06))
        body.closeSubpath()

        let lightCenter = lure - center
        graphics.fill(body, with: .radialGradient(
            Gradient(colors: [Color(hex: 0x2C4A52).opacity(0.25 + 0.6 * glow), Color(hex: 0x0A141A), Color(hex: 0x020509)]),
            center: center + lightCenter * 0.75, startRadius: 0, endRadius: scale * 0.9
        ))

        // Needle teeth along the jaw.
        var teeth = Path()
        for index in 0..<7 {
            let t = CGFloat(index) / 6
            let upper = center + CGPoint(x: scale * (0.33 - 0.15 * t), y: -scale * (0.06 - 0.08 * t))
            teeth.move(to: upper + CGPoint(x: -scale * 0.008, y: 0))
            teeth.addLine(to: upper + CGPoint(x: 0, y: scale * 0.05))
            teeth.addLine(to: upper + CGPoint(x: scale * 0.008, y: 0))
            let lower = center + CGPoint(x: scale * (0.35 - 0.17 * t), y: scale * 0.16 - (scale * 0.14 - gape) * t)
            teeth.move(to: lower + CGPoint(x: -scale * 0.008, y: 0))
            teeth.addLine(to: lower + CGPoint(x: 0, y: -scale * 0.045))
            teeth.addLine(to: lower + CGPoint(x: scale * 0.008, y: 0))
        }
        graphics.fill(teeth, with: .color(Color(hex: 0xBFD3CF).opacity(0.3 + 0.5 * glow)))

        // A dim, glassy eye catching the light.
        let eye = center + CGPoint(x: scale * 0.12, y: -scale * 0.2)
        graphics.fill(DeepSeaTheme.disc(eye, scale * 0.03), with: .color(Color(hex: 0x0F1E24)))
        graphics.fill(DeepSeaTheme.disc(eye + CGPoint(x: scale * 0.008, y: -scale * 0.008), scale * 0.008), with: .color(DeepSeaTheme.lure.opacity(0.4 + 0.5 * glow)))

        // Ragged fins.
        var fins = Path()
        let finRoot = center + CGPoint(x: -scale * 0.12, y: scale * 0.12)
        let flap = CGFloat(sin(frame.time * 1.5)) * scale * 0.03
        fins.addLines([finRoot, finRoot + CGPoint(x: -scale * 0.12, y: scale * 0.12 + flap), finRoot + CGPoint(x: -scale * 0.06, y: scale * 0.04 + flap), finRoot + CGPoint(x: -scale * 0.14, y: scale * 0.05 + flap)])
        fins.closeSubpath()
        graphics.fill(fins, with: .color(Color(hex: 0x0E1B21).opacity(0.9)))
    }
}
