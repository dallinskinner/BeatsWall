//
//  TwinklingTreeWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct TwinklingTreeWallpaper: View {
    let context: WallpaperContext

    private static let ornamentColors = [WinterTheme.red, WinterTheme.gold, WinterTheme.blue, Color(hex: 0xD8DEE9), Color(hex: 0xFF8FAB)]

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
        let floor = size.height * 0.84
        let treeBase = CGPoint(x: size.width * 0.5, y: floor - unit * 0.04)
        let treeHeight = unit * 0.68
        let treeWidth = treeHeight * 0.62
        let treeTop = treeBase.y - treeHeight

        // Room: wall, a snowy window and a wooden floor.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x3B2533), Color(hex: 0x24161F)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: floor)
        ))
        let window = CGRect(x: size.width * 0.74, y: size.height * 0.16, width: unit * 0.26, height: unit * 0.34)
        graphics.fill(Path(window.insetBy(dx: -unit * 0.012, dy: -unit * 0.012)), with: .color(Color(hex: 0x4A3040)))
        var outside = graphics
        outside.clip(to: Path(window))
        outside.fill(Path(window), with: .linearGradient(Gradient(colors: [WinterTheme.night, WinterTheme.dusk]), startPoint: CGPoint(x: 0, y: window.minY), endPoint: CGPoint(x: 0, y: window.maxY)))
        outside.translateBy(x: window.minX, y: window.minY)
        WinterTheme.drawSnowfall(in: &outside, size: window.size, time: frame.time, density: Double(audio.level), maxFlakes: 60)
        var mullions = Path(CGRect(x: window.midX - unit * 0.004, y: window.minY, width: unit * 0.008, height: window.height))
        mullions.addRect(CGRect(x: window.minX, y: window.midY - unit * 0.004, width: window.width, height: unit * 0.008))
        graphics.fill(mullions, with: .color(Color(hex: 0x4A3040)))
        graphics.fill(Path(CGRect(x: 0, y: floor, width: size.width, height: size.height - floor)), with: .color(Color(hex: 0x5A3A26)))
        var boards = Path()
        var y = floor + unit * 0.03
        while y < size.height {
            boards.addRect(CGRect(x: 0, y: y, width: size.width, height: max(1, unit * 0.002)))
            y += unit * 0.035
        }
        graphics.fill(boards, with: .color(Color(hex: 0x3E2618)))

        // Warm glow from the tree lights.
        var glow = graphics
        glow.blendMode = .plusLighter
        WinterTheme.glow(in: glow, at: CGPoint(x: treeBase.x, y: treeBase.y - treeHeight * 0.4), radius: unit * 0.55, color: WinterTheme.warm, opacity: 0.12 + 0.15 * Double(audio.level))

        // Tree: stacked tiers.
        graphics.fill(Path(CGRect(x: treeBase.x - unit * 0.025, y: treeBase.y - unit * 0.02, width: unit * 0.05, height: unit * 0.06)), with: .color(WinterTheme.woodDark))
        let tiers = 4
        for tier in 0..<tiers {
            let t = CGFloat(tier) / CGFloat(tiers)
            let bottom = treeBase.y - treeHeight * 0.75 * t
            let top = bottom - treeHeight * 0.4
            let half = treeWidth / 2 * (1 - t * 0.68)
            var shape = Path()
            shape.move(to: CGPoint(x: treeBase.x - half, y: bottom))
            shape.addLine(to: CGPoint(x: treeBase.x, y: max(top, treeTop)))
            shape.addLine(to: CGPoint(x: treeBase.x + half, y: bottom))
            shape.addQuadCurve(to: CGPoint(x: treeBase.x - half, y: bottom), control: CGPoint(x: treeBase.x, y: bottom + unit * 0.03))
            graphics.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x2F6B4F), WinterTheme.pineDark]),
                startPoint: CGPoint(x: treeBase.x - half, y: 0), endPoint: CGPoint(x: treeBase.x + half, y: 0)
            ))
        }

        // Garland swags that sparkle with the hi-hats.
        func halfWidth(at y: CGFloat) -> CGFloat {
            treeWidth / 2 * min(1, max(0, (y - treeTop) / treeHeight)) * 0.95
        }
        var garland = Path()
        var sparkles = Path()
        for swag in 0..<4 {
            let yLeft = treeTop + treeHeight * CGFloat(0.25 + 0.18 * Double(swag))
            let yRight = yLeft + treeHeight * 0.1
            let start = CGPoint(x: treeBase.x - halfWidth(at: yLeft) * 0.85, y: yLeft)
            let end = CGPoint(x: treeBase.x + halfWidth(at: yRight) * 0.85, y: yRight)
            garland.move(to: start)
            garland.addQuadCurve(to: end, control: CGPoint(x: treeBase.x, y: (yLeft + yRight) / 2 + unit * 0.05))
            for dot in 0..<12 where hash01(swag * 20 + dot, Int(frame.time * 6)) < 0.25 + 0.6 * Double(audio.treble) {
                let t = CGFloat(dot) / 11
                let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t + unit * 0.05 * 2 * t * (1 - t))
                sparkles.addPath(WinterTheme.disc(point, unit * 0.004))
            }
        }
        graphics.stroke(garland, with: .color(WinterTheme.gold.opacity(0.75)), style: StrokeStyle(lineWidth: unit * 0.006, lineCap: .round))
        glow.fill(sparkles, with: .color(.white))

        // Ornaments, each glowing with its own spectrum bin.
        for index in 0..<32 {
            // Stratified down the tree so ornaments cover it evenly.
            let ty = CGFloat(0.16 + 0.8 * (Double(index) + hash01(index, 5)) / 32)
            let y = treeTop + treeHeight * ty
            let side = Double((index * 7) % 11) / 10 + hash01(index, 6) * 0.08
            let x = treeBase.x + halfWidth(at: y) * CGFloat(side * 1.6 - 0.8)
            let energy = Double(audio.spectrum[index % AudioFeatures.binCount])
            let color = Self.ornamentColors[index % Self.ornamentColors.count]
            let r = unit * CGFloat(0.012 + 0.006 * hash01(index, 7))
            if energy > 0.35 {
                WinterTheme.glow(in: glow, at: CGPoint(x: x, y: y), radius: r * 4, color: color, opacity: 0.5 * energy)
            }
            graphics.fill(WinterTheme.disc(CGPoint(x: x, y: y), r), with: .radialGradient(
                Gradient(colors: [color.mix(with: .white, by: 0.25 + 0.5 * energy), color.mix(with: .black, by: 0.4 - 0.3 * energy)]),
                center: CGPoint(x: x - r * 0.3, y: y - r * 0.3), startRadius: 0, endRadius: r * 1.4
            ))
        }

        // The star pulses on the beat.
        let pulse = Double(audio.beatPulse)
        let starCenter = CGPoint(x: treeBase.x, y: treeTop - unit * 0.01)
        WinterTheme.glow(in: glow, at: starCenter, radius: unit * (0.08 + 0.08 * CGFloat(pulse)), color: WinterTheme.gold, opacity: 0.4 + 0.4 * pulse)
        graphics.fill(WinterTheme.star(center: starCenter, radius: unit * 0.04 * CGFloat(1 + 0.15 * pulse)), with: .color(WinterTheme.gold.mix(with: .white, by: 0.4 * pulse)))

        // Presents.
        let presents: [(CGFloat, CGFloat, CGFloat, Color, Color)] = [
            (-0.24, 0.1, 0.08, WinterTheme.red, WinterTheme.gold), (-0.12, 0.07, 0.06, WinterTheme.blue, .white),
            (0.13, 0.09, 0.07, WinterTheme.green, WinterTheme.red), (0.25, 0.06, 0.05, WinterTheme.gold, WinterTheme.red),
        ]
        for (dx, w, h, color, ribbon) in presents {
            let box = CGRect(x: treeBase.x + unit * dx - unit * w / 2, y: floor - unit * h, width: unit * w, height: unit * h)
            graphics.fill(Path(box), with: .color(color))
            var bands = Path(CGRect(x: box.midX - unit * 0.005, y: box.minY, width: unit * 0.01, height: box.height))
            bands.addRect(CGRect(x: box.minX, y: box.midY - unit * 0.005, width: box.width, height: unit * 0.01))
            graphics.fill(bands, with: .color(ribbon))
            graphics.fill(Path(ellipseIn: CGRect(x: box.midX - unit * 0.016, y: box.minY - unit * 0.012, width: unit * 0.014, height: unit * 0.014)), with: .color(ribbon))
            graphics.fill(Path(ellipseIn: CGRect(x: box.midX + unit * 0.002, y: box.minY - unit * 0.012, width: unit * 0.014, height: unit * 0.014)), with: .color(ribbon))
        }
    }
}
