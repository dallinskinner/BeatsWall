//
//  RooftopSunsetWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RooftopSunsetWallpaper: View {
    let context: WallpaperContext
    @State private var clouds = PhaseClock()

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
        let horizon = size.height * 0.66
        let drift = clouds.advance(to: frame.time, speed: 0.01 + 0.02 * Double(audio.level))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x5B4B8A), Color(hex: 0xC46F8A), Color(hex: 0xF28C6B), Color(hex: 0xFFD5A5)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        let sun = CGPoint(x: size.width * 0.3, y: horizon - unit * 0.2)
        LofiTheme.glow(in: graphics, at: sun, radius: unit * (0.3 + 0.08 * CGFloat(audio.bass)), color: Color(hex: 0xFFE3A3), opacity: 0.55)
        graphics.fill(LofiTheme.ellipse(sun, unit * 0.09, unit * 0.09), with: .color(Color(hex: 0xFFE9B8)))

        // Soft clouds drifting across.
        for index in 0..<6 {
            let span = size.width + unit * 0.8
            let x = (CGFloat(hash01(index, 1)) * span + CGFloat(drift) * unit * CGFloat(0.6 + hash01(index, 2))).truncatingRemainder(dividingBy: span) - unit * 0.4
            let y = size.height * CGFloat(0.08 + 0.35 * hash01(index, 3))
            let scale = unit * CGFloat(0.04 + 0.04 * hash01(index, 4))
            var cloud = Path()
            for (dx, dy, rx, ry) in [(-1.6, 0.1, 1.4, 0.55), (0.0, -0.15, 1.8, 0.75), (1.7, 0.1, 1.3, 0.5)] {
                cloud.addEllipse(in: CGRect(x: x + (dx - rx) * scale, y: y + (dy - ry) * scale, width: 2 * rx * scale, height: 2 * ry * scale))
            }
            graphics.fill(cloud, with: .color(Color(hex: 0xFFE1D0).opacity(0.55)))
        }

        // Birds flapping in time with the music.
        let beat = audio.beatProgress(at: frame.time)
        var birds = Path()
        for index in 0..<6 {
            let span = size.width + unit * 0.4
            let x = (CGFloat(hash01(index, 21)) * span + CGFloat(frame.time) * unit * CGFloat(0.025 + 0.02 * hash01(index, 22))).truncatingRemainder(dividingBy: span) - unit * 0.2
            let y = size.height * CGFloat(0.15 + 0.3 * hash01(index, 23)) + unit * 0.01 * CGFloat(sin(frame.time + Double(index)))
            let wing = unit * CGFloat(0.012 + 0.006 * hash01(index, 24))
            let flap = CGFloat(sin(2 * .pi * beat + Double(index) * 0.9)) * wing * 0.8
            birds.move(to: CGPoint(x: x - wing, y: y - flap))
            birds.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - wing * 0.5, y: y - flap * 0.5 - wing * 0.3))
            birds.addQuadCurve(to: CGPoint(x: x + wing, y: y - flap), control: CGPoint(x: x + wing * 0.5, y: y - flap * 0.5 - wing * 0.3))
        }
        graphics.stroke(birds, with: .color(Color(hex: 0x3A2F4C)), style: StrokeStyle(lineWidth: max(1, unit * 0.003), lineCap: .round, lineJoin: .round))

        // Far skyline, then a nearer one whose windows switch on with the spectrum.
        drawSkyline(in: &graphics, size: size, unit: unit, base: horizon, seed: 0, height: 0.13, color: Color(hex: 0x8A6A9A), windows: nil)
        drawSkyline(in: &graphics, size: size, unit: unit, base: horizon + unit * 0.08, seed: 50, height: 0.17, color: Color(hex: 0x4A3B5C), windows: audio)

        // Rooftop in the foreground.
        let roof = size.height * 0.84
        graphics.fill(Path(CGRect(x: 0, y: roof, width: size.width, height: size.height)), with: .color(Color(hex: 0x2E2540)))
        graphics.fill(Path(CGRect(x: 0, y: roof - unit * 0.025, width: size.width, height: unit * 0.025)), with: .color(Color(hex: 0x3A2F4C)))
        // Water tower.
        let tower = CGPoint(x: size.width * 0.14, y: roof - unit * 0.025)
        var legs = Path()
        for dx: CGFloat in [-0.06, 0.06] {
            legs.move(to: tower + CGPoint(x: unit * dx, y: 0))
            legs.addLine(to: tower + CGPoint(x: unit * dx * 0.8, y: -unit * 0.14))
        }
        legs.move(to: tower + CGPoint(x: -unit * 0.055, y: -unit * 0.06))
        legs.addLine(to: tower + CGPoint(x: unit * 0.055, y: -unit * 0.06))
        graphics.stroke(legs, with: .color(Color(hex: 0x2E2540)), lineWidth: unit * 0.008)
        let tank = CGRect(x: tower.x - unit * 0.07, y: tower.y - unit * 0.29, width: unit * 0.14, height: unit * 0.15)
        graphics.fill(Path(roundedRect: tank, cornerRadius: unit * 0.01), with: .color(Color(hex: 0x2E2540)))
        var roofCap = Path()
        roofCap.addLines([CGPoint(x: tank.minX - unit * 0.01, y: tank.minY), CGPoint(x: tank.midX, y: tank.minY - unit * 0.06), CGPoint(x: tank.maxX + unit * 0.01, y: tank.minY)])
        roofCap.closeSubpath()
        graphics.fill(roofCap, with: .color(Color(hex: 0x2E2540)))
        // Antenna with a blinking light on the beat.
        let antenna = CGPoint(x: size.width * 0.86, y: roof - unit * 0.025)
        var mast = Path()
        mast.addLines([antenna, antenna + CGPoint(x: 0, y: -unit * 0.22)])
        mast.move(to: antenna + CGPoint(x: -unit * 0.04, y: -unit * 0.15))
        mast.addLine(to: antenna + CGPoint(x: unit * 0.04, y: -unit * 0.15))
        mast.move(to: antenna + CGPoint(x: -unit * 0.025, y: -unit * 0.19))
        mast.addLine(to: antenna + CGPoint(x: unit * 0.025, y: -unit * 0.19))
        graphics.stroke(mast, with: .color(Color(hex: 0x2E2540)), lineWidth: unit * 0.005)
        let beacon = antenna + CGPoint(x: 0, y: -unit * 0.225)
        LofiTheme.glow(in: graphics, at: beacon, radius: unit * 0.03, color: Color(hex: 0xFF5A5F), opacity: 0.2 + 0.7 * Double(audio.beatPulse))
        graphics.fill(LofiTheme.ellipse(beacon, unit * 0.005, unit * 0.005), with: .color(Color(hex: 0xFF5A5F)))
    }

    private func drawSkyline(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, base: CGFloat, seed: Int, height: Double, color: Color, windows audio: AudioFeatures?) {
        var buildings = Path()
        var lit = Path()
        var x: CGFloat = -unit * 0.02
        var index = seed
        while x < size.width {
            let width = unit * CGFloat(0.06 + 0.07 * hash01(index, 1))
            let tall = unit * CGFloat(height * (0.35 + 0.65 * hash01(index, 2)))
            let rect = CGRect(x: x, y: base - tall, width: width, height: tall + size.height)
            buildings.addRect(rect)
            if let audio {
                let bin = min(Int(x / size.width * CGFloat(AudioFeatures.binCount)), AudioFeatures.binCount - 1)
                let energy = Double(audio.spectrum[max(bin, 0)])
                let rows = Int(tall / (unit * 0.022))
                for row in 0..<rows {
                    for column in 0..<3 where hash01(index * 7 + column, row) < 0.12 + 0.6 * energy {
                        lit.addRect(CGRect(x: x + width * (0.15 + 0.27 * CGFloat(column)), y: base - tall + unit * 0.012 + CGFloat(row) * unit * 0.022, width: width * 0.16, height: unit * 0.009))
                    }
                }
            }
            x += width + unit * 0.004
            index += 1
        }
        graphics.fill(buildings, with: .color(color))
        graphics.fill(lit, with: .color(Color(hex: 0xFFD27A).opacity(0.85)))
    }
}
