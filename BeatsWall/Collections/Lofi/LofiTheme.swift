//
//  LofiTheme.swift
//  BeatsWall
//

import SwiftUI

/// Warm, muted and soft: no outlines, just flat shapes, glow and grain.
enum LofiTheme {
    static let wall = Color(hex: 0x3A3560)
    static let wallDark = Color(hex: 0x2D2A4A)
    static let lamp = Color(hex: 0xFFB86B)
    static let wood = Color(hex: 0x8C5E3C)
    static let woodDark = Color(hex: 0x6B452B)
    static let pink = Color(hex: 0xE8A0A0)
    static let plant = Color(hex: 0x6A994E)
    static let plantDark = Color(hex: 0x4F7A3A)
    static let cream = Color(hex: 0xF2E8CF)
    static let ink = Color(hex: 0x1E1B2E)
    static let nightSky = Color(hex: 0x1D2549)
    static let teal = Color(hex: 0x5FA8A0)
    static let clay = Color(hex: 0xC9735A)

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.045))
    }

    static func ellipse(_ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }

    static func glow(in graphics: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        graphics.fill(ellipse(center, radius, radius), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    /// A rounded leaf from `base` toward `angle`.
    static func leaf(from base: CGPoint, angle: Double, length: CGFloat, width: CGFloat) -> Path {
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let tip = base + direction * length
        let middle = base + direction * (length * 0.5)
        var path = Path()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: middle + normal * width)
        path.addQuadCurve(to: base, control: middle - normal * width)
        path.closeSubpath()
        return path
    }
}
