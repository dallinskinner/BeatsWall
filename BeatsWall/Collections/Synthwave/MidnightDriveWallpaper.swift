//
//  MidnightDriveWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct MidnightDriveWallpaper: View {
    let context: WallpaperContext
    @State private var road = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.02)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.52
        let center = size.width / 2
        let depth = size.height - horizon
        let scroll = road.advance(to: frame.time, speed: 1.2 + 2.5 * SynthwaveTheme.tempo(audio) + Double(audio.level))
        let offset = scroll - scroll.rounded(.down)

        graphics.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)), with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.deepNight, SynthwaveTheme.dusk, SynthwaveTheme.purple]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        SynthwaveTheme.drawStars(in: &graphics, size: size, maxY: horizon * 0.7, count: 110, twinkle: Double(audio.treble), time: frame.time)
        SynthwaveTheme.drawSun(in: &graphics, center: CGPoint(x: center, y: horizon - unit * 0.05), radius: unit * 0.2, bass: Double(audio.bass), scroll: frame.time * 0.15)

        // Skyline equalizer on the horizon.
        let buildings = 36
        let slot = size.width / CGFloat(buildings)
        var skyline = Path()
        var windows = Path()
        for index in 0..<buildings {
            let bin = min(Int(abs(Double(index) / Double(buildings - 1) - 0.5) * 2 * 30), AudioFeatures.binCount - 1)
            let height = unit * CGFloat(0.03 + 0.05 * hash01(index, 5) + 0.12 * Double(audio.spectrum[AudioFeatures.binCount - 1 - bin]))
            let rect = CGRect(x: CGFloat(index) * slot + slot * 0.08, y: horizon - height, width: slot * 0.84, height: height)
            skyline.addRect(rect)
            var y = rect.minY + unit * 0.012
            while y < horizon - unit * 0.01 {
                for column in 0..<2 where hash01(index * 7 + column, Int(y)) > 0.55 {
                    windows.addRect(CGRect(x: rect.minX + rect.width * (0.22 + 0.4 * CGFloat(column)), y: y, width: rect.width * 0.16, height: unit * 0.006))
                }
                y += unit * 0.016
            }
        }
        graphics.fill(skyline, with: .color(SynthwaveTheme.night))
        graphics.fill(windows, with: .color(SynthwaveTheme.cyan.opacity(0.7)))
        var skylineEdge = Path()
        skylineEdge.addLines([CGPoint(x: 0, y: horizon), CGPoint(x: size.width, y: horizon)])
        SynthwaveTheme.neon(skylineEdge, in: graphics, color: SynthwaveTheme.magenta, width: max(1, unit * 0.002))

        // Ground and road.
        graphics.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: depth)), with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.night, SynthwaveTheme.deepNight]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
        ))
        let roadHalf = size.width * 0.62
        var roadShape = Path()
        roadShape.addLines([CGPoint(x: center - unit * 0.01, y: horizon), CGPoint(x: center + unit * 0.01, y: horizon), CGPoint(x: center + roadHalf, y: size.height), CGPoint(x: center - roadHalf, y: size.height)])
        roadShape.closeSubpath()
        graphics.fill(roadShape, with: .color(Color(hex: 0x140629)))
        for side: CGFloat in [-1, 1] {
            var edge = Path()
            edge.addLines([CGPoint(x: center + side * unit * 0.01, y: horizon), CGPoint(x: center + side * roadHalf, y: size.height)])
            SynthwaveTheme.neon(edge, in: graphics, color: SynthwaveTheme.cyan, width: max(1, unit * 0.003))
        }

        // Lane dashes and street lamps rushing past in perspective.
        var dashes = Path()
        for index in 0..<30 {
            let near = Double(index) + 1 - offset
            let far = near + 0.45
            let yNear = horizon + depth / CGFloat(near)
            let yFar = horizon + depth / CGFloat(far)
            guard yFar < size.height else { continue }
            let halfNear = unit * 0.012 / CGFloat(near)
            let halfFar = unit * 0.012 / CGFloat(far)
            dashes.addLines([CGPoint(x: center - halfFar, y: yFar), CGPoint(x: center + halfFar, y: yFar), CGPoint(x: center + halfNear, y: min(yNear, size.height)), CGPoint(x: center - halfNear, y: min(yNear, size.height))])
            dashes.closeSubpath()
        }
        graphics.fill(dashes, with: .color(SynthwaveTheme.yellow.opacity(0.85)))

        let lampOffset = (scroll / 2) - (scroll / 2).rounded(.down)
        for index in 0..<10 {
            let z = (Double(index) + 1 - lampOffset) * 2 - 1
            guard z > 0.35 else { continue }
            let y = horizon + depth / CGFloat(z)
            let height = unit * 0.45 / CGFloat(z)
            for side: CGFloat in [-1, 1] {
                let x = center + side * roadHalf * 1.12 / CGFloat(z)
                var pole = Path()
                pole.addLines([CGPoint(x: x, y: y), CGPoint(x: x, y: y - height), CGPoint(x: x - side * height * 0.18, y: y - height)])
                graphics.stroke(pole, with: .color(Color(hex: 0x4A1F80)), lineWidth: max(1, unit * 0.008 / CGFloat(z)))
                let lamp = CGPoint(x: x - side * height * 0.18, y: y - height)
                let glow = unit * 0.05 / CGFloat(z) * CGFloat(1 + 0.6 * Double(audio.beatPulse))
                graphics.fill(
                    Path(ellipseIn: CGRect(x: lamp.x - glow, y: lamp.y - glow, width: glow * 2, height: glow * 2)),
                    with: .radialGradient(Gradient(colors: [SynthwaveTheme.magenta, SynthwaveTheme.magenta.opacity(0)]), center: lamp, startRadius: 0, endRadius: glow)
                )
            }
        }

        drawCar(in: &graphics, size: size, unit: unit, frame: frame)
    }

    private func drawCar(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let width = unit * 0.5
        let bounce = unit * 0.006 * CGFloat(audio.bass) + unit * 0.002 * CGFloat(sin(frame.time * 9))
        let bottom = size.height * 0.95 - bounce
        let left = size.width / 2 - width / 2
        let bodyHeight = width * 0.26
        let body = CGRect(x: left, y: bottom - bodyHeight, width: width, height: bodyHeight)

        for side: CGFloat in [0.06, 0.8] {
            graphics.fill(Path(roundedRect: CGRect(x: left + width * side, y: bottom - width * 0.03, width: width * 0.14, height: width * 0.07), cornerRadius: width * 0.015), with: .color(.black))
        }
        var cabin = Path()
        cabin.addLines([
            CGPoint(x: left + width * 0.12, y: body.minY), CGPoint(x: left + width * 0.24, y: body.minY - width * 0.17),
            CGPoint(x: left + width * 0.76, y: body.minY - width * 0.17), CGPoint(x: left + width * 0.88, y: body.minY),
        ])
        cabin.closeSubpath()
        graphics.fill(cabin, with: .color(Color(hex: 0x1D0A3A)))
        var window = Path()
        window.addLines([
            CGPoint(x: left + width * 0.17, y: body.minY - width * 0.012), CGPoint(x: left + width * 0.26, y: body.minY - width * 0.15),
            CGPoint(x: left + width * 0.74, y: body.minY - width * 0.15), CGPoint(x: left + width * 0.83, y: body.minY - width * 0.012),
        ])
        window.closeSubpath()
        graphics.fill(window, with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.purple, SynthwaveTheme.magenta.opacity(0.8)]),
            startPoint: CGPoint(x: 0, y: body.minY - width * 0.15), endPoint: CGPoint(x: 0, y: body.minY)
        ))
        let bodyPath = Path(roundedRect: body, cornerRadius: width * 0.04)
        graphics.fill(bodyPath, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2B1050), Color(hex: 0x12002B)]),
            startPoint: CGPoint(x: 0, y: body.minY), endPoint: CGPoint(x: 0, y: body.maxY)
        ))
        SynthwaveTheme.neon(Path(roundedRect: body, cornerRadius: width * 0.04), in: graphics, color: SynthwaveTheme.magenta, width: max(1, unit * 0.0015), brightness: 0.6)

        // Full-width taillight strip pulsing with the bass.
        let light = CGRect(x: left + width * 0.04, y: body.minY + bodyHeight * 0.22, width: width * 0.92, height: bodyHeight * 0.2)
        let intensity = 0.55 + 0.45 * Double(audio.bass)
        graphics.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(hex: 0xFF2E57).opacity(intensity), radius: unit * (0.01 + 0.03 * CGFloat(audio.bass))))
            layer.fill(Path(roundedRect: light, cornerRadius: light.height / 2), with: .color(Color(hex: 0xFF2E57).mix(with: .white, by: 0.25 * intensity)))
        }
        var slats = Path()
        for index in 1..<12 {
            let x = light.minX + light.width * CGFloat(index) / 12
            slats.move(to: CGPoint(x: x, y: light.minY))
            slats.addLine(to: CGPoint(x: x, y: light.maxY))
        }
        graphics.stroke(slats, with: .color(Color(hex: 0x7A0A2A).opacity(0.6)), lineWidth: max(1, unit * 0.0015))

        let plate = CGRect(x: size.width / 2 - width * 0.1, y: body.minY + bodyHeight * 0.55, width: width * 0.2, height: bodyHeight * 0.28)
        graphics.fill(Path(roundedRect: plate, cornerRadius: width * 0.008), with: .color(Color(hex: 0xE8E4F0)))
        let label = graphics.resolve(Text("BEATS").font(.system(size: plate.height * 0.7, weight: .heavy, design: .monospaced)).foregroundStyle(SynthwaveTheme.night))
        graphics.draw(label, at: CGPoint(x: plate.midX, y: plate.midY))
    }
}
