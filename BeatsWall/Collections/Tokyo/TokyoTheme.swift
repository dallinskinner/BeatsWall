//
//  TokyoTheme.swift
//  BeatsWall
//

import SwiftUI

/// Rainy neon nights.
enum TokyoTheme {
    static let night = Color(hex: 0x0A0E1F)
    static let navy = Color(hex: 0x161C38)
    static let haze = Color(hex: 0x3A2850)
    static let building = Color(hex: 0x0F1326)
    static let asphalt = Color(hex: 0x0E1019)
    static let pink = Color(hex: 0xFF3D7F)
    static let cyan = Color(hex: 0x2DE2E6)
    static let amber = Color(hex: 0xFFB000)
    static let red = Color(hex: 0xFF2A2A)
    static let purple = Color(hex: 0xB06BFF)
    static let lantern = Color(hex: 0xE63946)
    static let warm = Color(hex: 0xFFD6A0)

    static let neonColors = [pink, cyan, amber, purple, red]

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.035))
    }

    /// Kana-like neon glyphs: a few short strokes per cell, deterministic per seed.
    static func glyphs(in rect: CGRect, count: Int, vertical: Bool, seed: Int) -> Path {
        var path = Path()
        let cell = vertical ? rect.height / CGFloat(count) : rect.width / CGFloat(count)
        for index in 0..<count {
            let origin = vertical ? CGPoint(x: rect.minX, y: rect.minY + CGFloat(index) * cell) : CGPoint(x: rect.minX + CGFloat(index) * cell, y: rect.minY)
            let box = CGRect(origin: origin, size: vertical ? CGSize(width: rect.width, height: cell) : CGSize(width: cell, height: rect.height)).insetBy(dx: cell * 0.2, dy: cell * 0.2)
            let strokes = 2 + Int(hash01(seed, index) * 3)
            for stroke in 0..<strokes {
                let kind = Int(hash01(seed * 7 + index, stroke) * 4)
                let a = CGFloat(hash01(seed * 13 + index, stroke))
                let b = CGFloat(hash01(seed * 17 + index, stroke))
                switch kind {
                case 0: // horizontal
                    path.move(to: CGPoint(x: box.minX + box.width * a * 0.3, y: box.minY + box.height * b))
                    path.addLine(to: CGPoint(x: box.maxX - box.width * b * 0.3, y: box.minY + box.height * b))
                case 1: // vertical
                    path.move(to: CGPoint(x: box.minX + box.width * a, y: box.minY + box.height * b * 0.3))
                    path.addLine(to: CGPoint(x: box.minX + box.width * a, y: box.maxY))
                case 2: // sweeping diagonal
                    path.move(to: CGPoint(x: box.minX + box.width * (0.3 + 0.4 * a), y: box.minY))
                    path.addQuadCurve(to: CGPoint(x: box.minX, y: box.maxY), control: CGPoint(x: box.midX, y: box.midY + box.height * 0.2 * b))
                default: // hook
                    path.move(to: CGPoint(x: box.minX + box.width * 0.2, y: box.minY + box.height * a))
                    path.addLine(to: CGPoint(x: box.maxX, y: box.minY + box.height * a))
                    path.addLine(to: CGPoint(x: box.maxX - box.width * 0.2, y: box.maxY))
                }
            }
        }
        return path
    }

    /// A neon sign: dark panel, glowing border and glyphs.
    static func drawSign(in graphics: GraphicsContext, rect: CGRect, glyphCount: Int, vertical: Bool, seed: Int, color: Color, brightness: Double) {
        let unit = min(rect.width, rect.height)
        graphics.fill(Path(roundedRect: rect, cornerRadius: unit * 0.08), with: .color(Color(hex: 0x07080F).opacity(0.9)))
        SynthwaveTheme.neon(Path(roundedRect: rect.insetBy(dx: unit * 0.06, dy: unit * 0.06), cornerRadius: unit * 0.06), in: graphics, color: color, width: max(1, unit * 0.025), brightness: brightness * 0.8)
        SynthwaveTheme.neon(glyphs(in: rect.insetBy(dx: unit * 0.1, dy: unit * 0.1), count: glyphCount, vertical: vertical, seed: seed), in: graphics, color: color, width: max(1, unit * 0.045), brightness: brightness)
    }

    static func drawRain(in graphics: inout GraphicsContext, size: CGSize, time: Double, density: Double, slant: CGFloat = 0.12) {
        let unit = min(size.width, size.height)
        var rain = Path()
        let count = Int(80 + 220 * density)
        for index in 0..<count {
            let speed = 1.4 + hash01(index, 91)
            let fall = (hash01(index, 92) + time * speed * 0.7).truncatingRemainder(dividingBy: 1)
            let length = unit * CGFloat(0.02 + 0.03 * hash01(index, 93))
            let x = CGFloat(hash01(index, 94)) * (size.width + unit * 0.2) - unit * 0.1 + CGFloat(fall) * size.height * slant
            let y = CGFloat(fall) * (size.height + length) - length
            rain.move(to: CGPoint(x: x, y: y))
            rain.addLine(to: CGPoint(x: x - length * slant, y: y - length))
        }
        graphics.stroke(rain, with: .color(Color(hex: 0xBFD7FF).opacity(0.22)), lineWidth: max(1, unit * 0.0012))
    }

    /// Distant skyline with dim windows.
    static func drawSkyline(in graphics: inout GraphicsContext, size: CGSize, base: CGFloat, height: CGFloat, seed: Int, color: Color, windowColor: Color, spectrum: [Float]?) {
        let unit = min(size.width, size.height)
        var buildings = Path()
        var windows = Path()
        var x: CGFloat = -unit * 0.02
        var index = seed
        while x < size.width {
            let width = unit * CGFloat(0.05 + 0.08 * hash01(index, 1))
            let tall = height * CGFloat(0.35 + 0.65 * hash01(index, 2))
            buildings.addRect(CGRect(x: x, y: base - tall, width: width, height: tall + unit))
            let bin = min(max(Int(x / size.width * CGFloat(AudioFeatures.binCount)), 0), AudioFeatures.binCount - 1)
            let energy = spectrum.map { Double($0[bin]) } ?? 0.3
            var y = base - tall + unit * 0.012
            var row = 0
            while y < base - unit * 0.01 {
                for column in 0..<3 where hash01(index * 5 + column, row) < 0.15 + 0.55 * energy {
                    windows.addRect(CGRect(x: x + width * (0.15 + 0.28 * CGFloat(column)), y: y, width: width * 0.14, height: unit * 0.007))
                }
                y += unit * 0.018
                row += 1
            }
            x += width + unit * 0.003
            index += 1
        }
        graphics.fill(buildings, with: .color(color))
        graphics.fill(windows, with: .color(windowColor))
    }
}
