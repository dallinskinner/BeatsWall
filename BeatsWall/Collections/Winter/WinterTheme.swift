//
//  WinterTheme.swift
//  BeatsWall
//

import SwiftUI

/// Cold blues, soft snow and warm holiday lights.
enum WinterTheme {
    static let night = Color(hex: 0x0E1A33)
    static let deep = Color(hex: 0x1B2D52)
    static let dusk = Color(hex: 0x3A4E7A)
    static let snow = Color(hex: 0xEEF4FF)
    static let snowShade = Color(hex: 0xB9C9E6)
    static let pine = Color(hex: 0x1F4A3A)
    static let pineDark = Color(hex: 0x143326)
    static let wood = Color(hex: 0x6B3E22)
    static let woodDark = Color(hex: 0x4A2A17)
    static let warm = Color(hex: 0xFFC46B)
    static let red = Color(hex: 0xE63946)
    static let green = Color(hex: 0x2A9D8F)
    static let gold = Color(hex: 0xFFD166)
    static let blue = Color(hex: 0x4EA8DE)

    static let bulbColors = [red, gold, green, blue, Color(hex: 0xFF8FAB)]

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.03))
    }

    static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func glow(in graphics: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        graphics.fill(disc(center, radius), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    /// Gently swaying snowfall; more flakes when `density` is higher.
    static func drawSnowfall(in graphics: inout GraphicsContext, size: CGSize, time: Double, density: Double, maxFlakes: Int = 400) {
        let unit = min(size.width, size.height)
        var near = Path()
        var far = Path()
        let count = Int(Double(maxFlakes) * (0.3 + 0.7 * density))
        for index in 0..<count {
            let depth = hash01(index, 71)
            let speed = 0.04 + 0.08 * depth
            let fall = (hash01(index, 72) + time * speed).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(hash01(index, 73)) * size.width + unit * 0.02 * CGFloat(sin(time * (0.5 + depth) + Double(index)))
            let y = CGFloat(fall) * (size.height + unit * 0.02) - unit * 0.01
            let r = unit * CGFloat(0.0015 + 0.003 * depth)
            if depth > 0.6 { near.addPath(disc(CGPoint(x: x, y: y), r)) } else { far.addPath(disc(CGPoint(x: x, y: y), r)) }
        }
        graphics.fill(far, with: .color(snow.opacity(0.55)))
        graphics.fill(near, with: .color(snow.opacity(0.9)))
    }

    /// A snow-dusted pine: stacked tiers with white caps.
    static func pinePath(base: CGPoint, height: CGFloat, tiers: Int = 4) -> (tree: Path, snow: Path) {
        var tree = Path()
        var snowCaps = Path()
        let width = height * 0.55
        tree.addRect(CGRect(x: base.x - width * 0.06, y: base.y - height * 0.12, width: width * 0.12, height: height * 0.12))
        for tier in 0..<tiers {
            let t = CGFloat(tier) / CGFloat(tiers)
            let bottom = base.y - height * 0.1 - height * 0.8 * t * 0.85
            let top = bottom - height * 0.42
            let half = width / 2 * (1 - t * 0.7)
            tree.addLines([CGPoint(x: base.x - half, y: bottom), CGPoint(x: base.x, y: top), CGPoint(x: base.x + half, y: bottom)])
            tree.closeSubpath()
            snowCaps.addLines([
                CGPoint(x: base.x - half * 0.35, y: top + (bottom - top) * 0.35),
                CGPoint(x: base.x, y: top),
                CGPoint(x: base.x + half * 0.35, y: top + (bottom - top) * 0.35),
                CGPoint(x: base.x + half * 0.15, y: top + (bottom - top) * 0.3),
                CGPoint(x: base.x - half * 0.1, y: top + (bottom - top) * 0.38),
            ])
            snowCaps.closeSubpath()
        }
        return (tree, snowCaps)
    }

    static func star(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.addLines((0..<10).map { index in
            let angle = Double(index) / 10 * 2 * .pi - .pi / 2
            let r = index % 2 == 0 ? radius : radius * 0.45
            return center + CGPoint(x: cos(angle) * r, y: sin(angle) * r)
        })
        path.closeSubpath()
        return path
    }

    /// Whether bulb `index` is lit in this beat's blink pattern.
    static func bulbLit(_ index: Int, beat: Int) -> Bool {
        switch (beat / 4) % 4 {
        case 0: return true
        case 1: return (index + beat) % 2 == 0
        case 2: return (index + beat) % 3 == 0
        default: return hash01(index, beat) > 0.4
        }
    }
}
