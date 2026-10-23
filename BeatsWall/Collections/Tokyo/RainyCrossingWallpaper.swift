//
//  RainyCrossingWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RainyCrossingWallpaper: View {
    let context: WallpaperContext

    /// Vertical signs: x as a fraction of width, top and height as fractions of the street line.
    private static let signs: [(x: CGFloat, top: CGFloat, height: CGFloat, glyphs: Int, color: Int)] = [
        (0.04, 0.12, 0.6, 4, 0), (0.13, 0.25, 0.45, 3, 1), (0.22, 0.08, 0.5, 4, 2),
        (0.74, 0.1, 0.55, 4, 3), (0.83, 0.3, 0.42, 3, 0), (0.92, 0.06, 0.62, 5, 1),
    ]

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
        let street = size.height * 0.64

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [TokyoTheme.night, TokyoTheme.navy, TokyoTheme.haze]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: street)
        ))
        TokyoTheme.drawSkyline(in: &graphics, size: size, base: street, height: size.height * 0.45, seed: 3, color: Color(hex: 0x1A1F3D), windowColor: TokyoTheme.warm.opacity(0.35), spectrum: nil)

        // The scene above the street: buildings at the edges carrying the signs.
        func drawSigns(in context: GraphicsContext) {
            var walls = Path()
            walls.addRect(CGRect(x: 0, y: 0, width: size.width * 0.3, height: street))
            walls.addRect(CGRect(x: size.width * 0.7, y: 0, width: size.width * 0.3, height: street))
            context.fill(walls, with: .color(TokyoTheme.building))
            for (index, sign) in Self.signs.enumerated() {
                let bin = (index * 5 + 2) % AudioFeatures.binCount
                var brightness = 0.3 + 0.7 * Double(audio.spectrum[bin])
                // A couple of signs have a dodgy tube.
                if index % 3 == 1, sin(frame.time * 23 + Double(index)) > 0.7 { brightness *= 0.3 }
                let width = unit * 0.075
                let rect = CGRect(x: size.width * sign.x, y: street * sign.top, width: width, height: street * sign.height)
                TokyoTheme.drawSign(in: context, rect: rect, glyphCount: sign.glyphs, vertical: true, seed: index + 1, color: TokyoTheme.neonColors[sign.color], brightness: brightness)
            }
            // A wide billboard across the back.
            let board = CGRect(x: size.width * 0.38, y: street * 0.28, width: size.width * 0.24, height: unit * 0.08)
            TokyoTheme.drawSign(in: context, rect: board, glyphCount: 6, vertical: false, seed: 42, color: TokyoTheme.cyan, brightness: 0.5 + 0.5 * Double(audio.beatPulse))
        }
        drawSigns(in: graphics)

        // Wet street with the signs mirrored in it.
        graphics.fill(Path(CGRect(x: 0, y: street, width: size.width, height: size.height - street)), with: .color(TokyoTheme.asphalt))
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.012))
            layer.opacity = 0.4
            layer.clip(to: Path(CGRect(x: 0, y: street, width: size.width, height: size.height - street)))
            layer.translateBy(x: 0, y: street * 2)
            layer.scaleBy(x: 1, y: -1)
            drawSigns(in: layer)
        }
        // Ripples breaking up the reflection.
        var ripples = Path()
        for index in 0..<26 {
            let y = street + (size.height - street) * CGFloat(hash01(index, 3))
            let x = CGFloat(hash01(index, 4)) * size.width + CGFloat(sin(frame.time * 0.8 + Double(index))) * unit * 0.02
            ripples.addRect(CGRect(x: x, y: y, width: unit * CGFloat(0.05 + 0.1 * hash01(index, 5)), height: max(1, unit * 0.002)))
        }
        graphics.fill(ripples, with: .color(TokyoTheme.asphalt.opacity(0.85)))

        // Zebra crossing in perspective.
        var stripes = Path()
        let near = size.height * 0.98
        for index in 0..<9 {
            let t0 = CGFloat(index) / 9, t1 = t0 + 0.06
            let farLeft = size.width * (0.35 + 0.3 * t0), farRight = size.width * (0.35 + 0.3 * t1)
            let nearLeft = size.width * (0.05 + 0.9 * t0), nearRight = size.width * (0.05 + 0.9 * t1)
            stripes.addLines([CGPoint(x: farLeft, y: street + unit * 0.06), CGPoint(x: farRight, y: street + unit * 0.06), CGPoint(x: nearRight, y: near), CGPoint(x: nearLeft, y: near)])
            stripes.closeSubpath()
        }
        graphics.fill(stripes, with: .color(Color(hex: 0xD8DCE8).opacity(0.28)))

        drawWalkers(in: &graphics, size: size, unit: unit, street: street, frame: frame)
        TokyoTheme.drawRain(in: &graphics, size: size, time: frame.time, density: 0.4 + 0.6 * Double(audio.level))
    }

    /// Umbrella silhouettes crossing, stepping in tempo.
    private func drawWalkers(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, street: CGFloat, frame: AudioFrame) {
        let beat = frame.audio.beatProgress(at: frame.time)
        let umbrellaColors = [TokyoTheme.pink, Color(hex: 0x2A2F4A), TokyoTheme.cyan.opacity(0.7), Color(hex: 0x2A2F4A)]
        for index in 0..<4 {
            let direction: CGFloat = index % 2 == 0 ? 1 : -1
            let span = size.width + unit * 0.4
            let raw = CGFloat(hash01(index, 8)) * span + direction * CGFloat(frame.time) * unit * 0.035
            let travel = raw - (raw / span).rounded(.down) * span - unit * 0.2
            let x = direction > 0 ? travel : size.width - travel
            let ground = street + unit * CGFloat(0.16 + 0.14 * hash01(index, 9))
            let scale = unit * CGFloat(0.12 + 0.08 * hash01(index, 9))
            let bob = CGFloat(abs(sin(.pi * beat))) * scale * 0.04
            var body = Path(roundedRect: CGRect(x: x - scale * 0.12, y: ground - scale * 0.85 - bob, width: scale * 0.24, height: scale * 0.55), cornerRadius: scale * 0.08)
            let stride = CGFloat(sin(.pi * beat)) * scale * 0.12
            body.addRect(CGRect(x: x - scale * 0.08 + stride, y: ground - scale * 0.32, width: scale * 0.07, height: scale * 0.32))
            body.addRect(CGRect(x: x + scale * 0.02 - stride, y: ground - scale * 0.32, width: scale * 0.07, height: scale * 0.32))
            graphics.fill(body, with: .color(Color(hex: 0x05060C)))
            var umbrella = Path()
            umbrella.move(to: CGPoint(x: x - scale * 0.42, y: ground - scale * 0.95 - bob))
            umbrella.addQuadCurve(to: CGPoint(x: x + scale * 0.42, y: ground - scale * 0.95 - bob), control: CGPoint(x: x, y: ground - scale * 1.45 - bob))
            umbrella.closeSubpath()
            graphics.fill(umbrella, with: .color(umbrellaColors[index]))
        }
    }
}
