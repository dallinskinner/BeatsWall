//
//  JungleTheme.swift
//  BeatsWall
//

import SwiftUI

/// Lush layered greens and warm, dappled light.
enum JungleTheme {
    static let deep = Color(hex: 0x0B2A1C)
    static let shade = Color(hex: 0x123D29)
    static let mid = Color(hex: 0x1E5A3A)
    static let leaf = Color(hex: 0x2E8B57)
    static let leafLight = Color(hex: 0x6BBF59)
    static let lime = Color(hex: 0xB5E655)
    static let sun = Color(hex: 0xFFE9A8)
    static let mist = Color(hex: 0xDDEFE3)
    static let bark = Color(hex: 0x5A3A22)
    static let red = Color(hex: 0xE63946)
    static let blue = Color(hex: 0x1D7FD8)
    static let yellow = Color(hex: 0xFFC300)
    static let frogGlow = Color(hex: 0x7CFFB2)

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

    /// A broad split leaf (monstera-like) on a stem from `base` toward `angle`.
    static func monstera(base: CGPoint, angle: Double, length: CGFloat) -> (leaf: Path, stem: Path) {
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let stemEnd = base + direction * (length * 0.35)
        let tip = stemEnd + direction * (length * 0.65)
        let width = length * 0.36
        var leaf = Path()
        leaf.move(to: stemEnd)
        leaf.addCurve(to: tip, control1: stemEnd + normal * (width * 1.3) + direction * (length * 0.05), control2: tip + normal * (width * 0.6) - direction * (length * 0.15))
        leaf.addCurve(to: stemEnd, control1: tip - normal * (width * 0.6) - direction * (length * 0.15), control2: stemEnd - normal * (width * 1.3) + direction * (length * 0.05))
        leaf.closeSubpath()
        // Slits cut in from the edges (drawn later in the background color by callers wanting depth).
        var stem = Path()
        stem.move(to: base)
        stem.addLine(to: stemEnd + direction * (length * 0.5))
        return (leaf, stem)
    }

    /// The slits of a monstera leaf, as thin wedges from the midrib to the edge.
    static func monsteraSlits(base: CGPoint, angle: Double, length: CGFloat) -> Path {
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let stemEnd = base + direction * (length * 0.35)
        var slits = Path()
        for index in 1...4 {
            let t = CGFloat(index) / 5
            let rib = stemEnd + direction * (length * 0.65 * t)
            let reach = length * 0.36 * (1 - abs(t - 0.4))
            for side: CGFloat in [-1, 1] {
                slits.move(to: rib + normal * (side * reach * 0.35))
                slits.addLine(to: rib + normal * (side * reach * 1.1) + direction * (length * 0.06))
                slits.addLine(to: rib + normal * (side * reach * 1.1) + direction * (length * 0.1))
                slits.closeSubpath()
            }
        }
        return slits
    }

    /// A long feathery palm frond.
    static func frond(base: CGPoint, angle: Double, length: CGFloat, droop: CGFloat) -> Path {
        var path = Path()
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        func spine(_ t: CGFloat) -> CGPoint { base + direction * (length * t) + CGPoint(x: 0, y: droop * t * t) }
        for index in 0..<14 {
            let t = 0.15 + 0.85 * CGFloat(index) / 14
            let point = spine(t)
            let leaflet = length * 0.22 * (1 - t * 0.6)
            for side: CGFloat in [-1, 1] {
                let tip = point + normal * (side * leaflet) + direction * (leaflet * 0.5) + CGPoint(x: 0, y: leaflet * 0.3)
                path.move(to: point)
                path.addQuadCurve(to: tip, control: point + normal * (side * leaflet * 0.5) + direction * (leaflet * 0.4))
                path.addQuadCurve(to: point + direction * (length * 0.03), control: point + normal * (side * leaflet * 0.4) + direction * (leaflet * 0.1))
                path.closeSubpath()
            }
        }
        return path
    }
}
