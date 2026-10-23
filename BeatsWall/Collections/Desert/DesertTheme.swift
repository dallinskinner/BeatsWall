//
//  DesertTheme.swift
//  BeatsWall
//

import SwiftUI

/// Deep indigo night, moonlit sand and warm firelight.
enum DesertTheme {
    static let skyTop = Color(hex: 0x0D0A24)
    static let skyMid = Color(hex: 0x231A48)
    static let horizon = Color(hex: 0x5E3A5E)
    static let sandLit = Color(hex: 0x9B6A6A)
    static let sand = Color(hex: 0x5A3A4A)
    static let duneShadow = Color(hex: 0x2A1B34)
    static let silhouette = Color(hex: 0x140E1C)
    static let moon = Color(hex: 0xF3E7C9)
    static let fire = Color(hex: 0xFF8C2B)
    static let flame = Color(hex: 0xFFD45C)
    static let ember = Color(hex: 0xFF4D1A)

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.035))
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

    static func sky(in graphics: inout GraphicsContext, size: CGSize, horizon: CGFloat) {
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [skyTop, skyMid, DesertTheme.horizon]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
    }

    static func drawStars(in graphics: inout GraphicsContext, size: CGSize, maxY: CGFloat, count: Int, time: Double, twinkle: Double) {
        let unit = min(size.width, size.height)
        var dim = Path()
        var bright = Path()
        for index in 0..<count {
            let point = CGPoint(x: CGFloat(hash01(index, 401)) * size.width, y: CGFloat(hash01(index, 402)) * maxY)
            let shimmer = 0.5 + 0.5 * sin(time * (0.8 + 2 * hash01(index, 403)) + Double(index))
            let r = unit * 0.0014 * CGFloat(0.5 + hash01(index, 404) * 1.2 + twinkle * shimmer * 0.6)
            if hash01(index, 405) > 0.85 { bright.addPath(disc(point, r * 1.4)) } else { dim.addPath(disc(point, r)) }
        }
        graphics.fill(dim, with: .color(.white.opacity(0.6)))
        graphics.fill(bright, with: .color(.white.opacity(0.95)))
    }

    /// A saguaro: trunk with one or two upturned arms.
    static func cactus(base: CGPoint, height: CGFloat, seed: Int) -> Path {
        var path = Path()
        let width = height * 0.14
        path.addRoundedRect(in: CGRect(x: base.x - width / 2, y: base.y - height, width: width, height: height), cornerSize: CGSize(width: width / 2, height: width / 2))
        for side: CGFloat in [-1, 1] where hash01(seed, side < 0 ? 1 : 2) > 0.25 {
            let armY = base.y - height * CGFloat(0.35 + 0.25 * hash01(seed, side < 0 ? 3 : 4))
            let reach = width * 1.4
            let rise = height * CGFloat(0.2 + 0.15 * hash01(seed, side < 0 ? 5 : 6))
            let armWidth = width * 0.75
            path.addRoundedRect(in: CGRect(x: side < 0 ? base.x - reach - armWidth / 2 : base.x, y: armY - armWidth / 2, width: reach + armWidth / 2, height: armWidth), cornerSize: CGSize(width: armWidth / 2, height: armWidth / 2))
            path.addRoundedRect(in: CGRect(x: base.x + side * reach - armWidth / 2, y: armY - rise, width: armWidth, height: rise + armWidth / 2), cornerSize: CGSize(width: armWidth / 2, height: armWidth / 2))
        }
        return path
    }
}
