//
//  MegacityWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct MegacityWallpaper: View {
    let context: WallpaperContext

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.035)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x0B0716), Color(hex: 0x2A0E3A), Color(hex: 0x4A1240)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Three layers of towers, far to near, with flying traffic between them.
        for layer in 0..<3 {
            drawTowers(in: &graphics, size: size, unit: unit, layer: layer, frame: frame)
            drawTraffic(in: &graphics, size: size, unit: unit, lane: layer, frame: frame)
        }

        // Neon haze at street level.
        var haze = graphics
        haze.blendMode = .plusLighter
        haze.fill(Path(CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.4)), with: .linearGradient(
            Gradient(colors: [CyberTheme.magenta.opacity(0), CyberTheme.magenta.opacity(0.18 + 0.12 * Double(audio.bass))]),
            startPoint: CGPoint(x: 0, y: size.height * 0.6), endPoint: CGPoint(x: 0, y: size.height)
        ))
        TokyoTheme.drawRain(in: &graphics, size: size, time: frame.time, density: 0.5 + 0.5 * Double(audio.level), slant: 0.08)
    }

    private func drawTowers(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, layer: Int, frame: AudioFrame) {
        let audio = frame.audio
        let depth = Double(layer) / 2
        let color = Color(hex: 0x241A3E).mix(with: CyberTheme.black, by: depth)
        let count = 10 - layer * 2
        var towers = Path()
        var windows = Path()
        var screens: [(CGRect, Int)] = []
        for index in 0..<count {
            let seed = layer * 50 + index
            let width = size.width / CGFloat(count) * CGFloat(0.55 + 0.35 * hash01(seed, 1))
            let x = size.width * CGFloat((Double(index) + hash01(seed, 2) * 0.4) / Double(count)) - width * 0.2
            let top = size.height * CGFloat(0.05 + 0.35 * hash01(seed, 3) * (1 - depth * 0.5)) + CGFloat(layer) * unit * 0.08
            let rect = CGRect(x: x, y: top, width: width, height: size.height - top)
            towers.addRect(rect)
            // Antenna.
            towers.addRect(CGRect(x: rect.midX - unit * 0.002, y: top - unit * 0.05, width: unit * 0.004, height: unit * 0.05))
            var y = top + unit * 0.02
            var row = 0
            while y < size.height {
                for column in 0..<Int(width / (unit * 0.018)) where hash01(seed * 11 + column, row) > 0.62 {
                    windows.addRect(CGRect(x: rect.minX + unit * 0.006 + CGFloat(column) * unit * 0.018, y: y, width: unit * 0.008, height: unit * 0.006))
                }
                y += unit * 0.016
                row += 1
            }
            if hash01(seed, 4) > 0.45 {
                let screenHeight = min(rect.height * 0.25, unit * CGFloat(0.12 + 0.1 * depth))
                screens.append((CGRect(x: rect.minX + width * 0.12, y: top + rect.height * CGFloat(0.1 + 0.3 * hash01(seed, 5)), width: width * 0.76, height: screenHeight), seed))
            }
        }
        graphics.fill(towers, with: .color(color))
        graphics.fill(windows, with: .color(CyberTheme.cyan.opacity(0.18 + 0.2 * depth)))

        // Giant ad screens flashing with the music.
        var glow = graphics
        glow.blendMode = .plusLighter
        for (rect, seed) in screens {
            let neon = CyberTheme.neons[seed % CyberTheme.neons.count]
            let accent = CyberTheme.neons[(seed + 2) % CyberTheme.neons.count]
            let bin = (seed * 5) % AudioFeatures.binCount
            let energy = Double(audio.spectrum[bin])
            graphics.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [neon.opacity(0.35 + 0.5 * energy), accent.opacity(0.25 + 0.4 * energy)]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            ))
            // Each screen cycles through a few "ads" on the bar.
            var content = Path()
            switch (audio.beatCount / 4 + seed) % 3 {
            case 0:
                for bar in 0..<8 {
                    let h = rect.height * 0.8 * CGFloat(audio.spectrum[(bin + bar * 3) % AudioFeatures.binCount])
                    content.addRect(CGRect(x: rect.minX + rect.width * (0.06 + 0.11 * CGFloat(bar)), y: rect.maxY - rect.height * 0.1 - h, width: rect.width * 0.07, height: h))
                }
            case 1:
                let r = rect.height * 0.3 * CGFloat(1 + 0.3 * audio.beatPulse)
                content.addEllipse(in: CGRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2))
            default:
                let sweep = CGFloat((frame.time * 0.6 + Double(seed)).truncatingRemainder(dividingBy: 1))
                content.addRect(CGRect(x: rect.minX, y: rect.minY + rect.height * sweep, width: rect.width, height: rect.height * 0.12))
            }
            graphics.fill(content, with: .color(.white.opacity(0.7)))
            glow.fill(Path(rect.insetBy(dx: -unit * 0.02, dy: -unit * 0.02)), with: .color(neon.opacity(0.06 + 0.12 * energy)))
        }
    }

    /// Flying cars streaking across in lanes; nearer lanes are faster and bigger.
    private func drawTraffic(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, lane: Int, frame: AudioFrame) {
        let audio = frame.audio
        let y = size.height * CGFloat(0.3 + 0.18 * Double(lane))
        let scale = unit * CGFloat(0.012 + 0.012 * Double(lane))
        let speed = (0.08 + 0.08 * Double(lane)) * (0.7 + 0.8 * Double(audio.level))
        var bodies = Path()
        var head = Path()
        var tail = Path()
        for car in 0..<(4 + lane * 2) {
            let direction: CGFloat = (car + lane) % 2 == 0 ? 1 : -1
            let progress = (hash01(car, lane + 70) + frame.time * speed * (0.8 + 0.4 * hash01(car, lane + 71))).truncatingRemainder(dividingBy: 1)
            let travel = CGFloat(progress) * (size.width + unit * 0.4) - unit * 0.2
            let x = direction > 0 ? travel : size.width - travel
            let carY = y + CGFloat(hash01(car, lane + 72) - 0.5) * unit * 0.06
            bodies.addRoundedRect(in: CGRect(x: x - scale * 1.4, y: carY - scale * 0.35, width: scale * 2.8, height: scale * 0.7), cornerSize: CGSize(width: scale * 0.35, height: scale * 0.35))
            let front = x + direction * scale * 1.4
            let back = x - direction * scale * 1.4
            head.addEllipse(in: CGRect(x: front - scale * 0.15, y: carY - scale * 0.15, width: scale * 0.3, height: scale * 0.3))
            tail.move(to: CGPoint(x: back, y: carY))
            tail.addLine(to: CGPoint(x: back - direction * scale * 6, y: carY))
        }
        graphics.fill(bodies, with: .color(Color(hex: 0x1C1830)))
        var light = graphics
        light.blendMode = .plusLighter
        light.fill(head, with: .color(.white))
        light.stroke(tail, with: .linearGradient(Gradient(colors: [CyberTheme.red.opacity(0.8), CyberTheme.red.opacity(0.1)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: max(1, scale * 0.2), lineCap: .round))
    }
}
