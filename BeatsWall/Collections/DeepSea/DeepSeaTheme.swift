//
//  DeepSeaTheme.swift
//  BeatsWall
//

import SwiftUI

/// Darkness, light shafts and bioluminescence.
enum DeepSeaTheme {
    static let abyss = Color(hex: 0x02060F)
    static let deep = Color(hex: 0x04142A)
    static let midwater = Color(hex: 0x0A2A4A)
    static let shallow = Color(hex: 0x14506E)
    static let cyan = Color(hex: 0x5CF2FF)
    static let pink = Color(hex: 0xFF6FD8)
    static let violet = Color(hex: 0x8B6BFF)
    static let lure = Color(hex: 0xB8FFEC)

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

    /// Slanted shafts of light from the surface, slowly wavering.
    static func drawGodRays(in graphics: inout GraphicsContext, size: CGSize, time: Double, intensity: Double) {
        let unit = min(size.width, size.height)
        var rays = graphics
        rays.blendMode = .plusLighter
        for index in 0..<6 {
            let x = size.width * CGFloat(0.1 + 0.16 * Double(index)) + unit * 0.05 * CGFloat(sin(time * 0.15 + Double(index)))
            let width = unit * CGFloat(0.05 + 0.08 * hash01(index, 3))
            let length = size.height * CGFloat(0.6 + 0.4 * hash01(index, 4))
            var ray = Path()
            ray.addLines([CGPoint(x: x, y: 0), CGPoint(x: x + width, y: 0), CGPoint(x: x + width * 2.5 + length * 0.25, y: length), CGPoint(x: x + length * 0.25, y: length)])
            ray.closeSubpath()
            let shimmer = 0.6 + 0.4 * sin(time * (0.3 + 0.2 * hash01(index, 5)) + Double(index) * 2)
            rays.fill(ray, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x9FE8FF).opacity(0.12 * intensity * shimmer), .clear]),
                startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + length * 0.25, y: length)
            ))
        }
    }

    /// Drifting specks of marine snow.
    static func drawMarineSnow(in graphics: inout GraphicsContext, size: CGSize, time: Double, count: Int, brightness: Double = 0.5) {
        let unit = min(size.width, size.height)
        var specks = Path()
        for index in 0..<count {
            let fall = (hash01(index, 21) + time * (0.004 + 0.01 * hash01(index, 22))).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(hash01(index, 23)) * size.width + unit * 0.02 * CGFloat(sin(time * 0.3 + Double(index)))
            specks.addPath(disc(CGPoint(x: x, y: CGFloat(fall) * size.height), unit * 0.0012 * CGFloat(0.5 + hash01(index, 24))))
        }
        graphics.fill(specks, with: .color(Color(hex: 0xCFE8FF).opacity(brightness)))
    }
}
