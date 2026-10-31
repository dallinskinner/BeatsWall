//
//  BrandTheme.swift
//  BeatsWall
//

import SwiftUI

/// The BeatsWall look, from the app icon: a magenta → orange → yellow glow on deep navy.
enum BrandTheme {
    /// #FF2E97
    static let magenta = Color(hex: 0xFF2E97)
    /// #FF8C42
    static let orange = Color(hex: 0xFF8C42)
    /// #FFD23F
    static let yellow = Color(hex: 0xFFD23F)
    /// #7B2FF7
    static let violet = Color(hex: 0x7B2FF7)
    /// #FFF0F7, a warm white for highlights and text.
    static let glow = Color(hex: 0xFFF0F7)
    /// #2A0A4A
    static let plum = Color(hex: 0x2A0A4A)
    /// #0E1230
    static let navy = Color(hex: 0x0E1230)
    /// #070816
    static let ink = Color(hex: 0x070816)

    /// The icon's gradient at `t` (0 magenta, 0.5 orange, 1 yellow).
    static func gradient(_ t: Double) -> Color {
        let t = min(max(t, 0), 1)
        return t < 0.5 ? magenta.mix(with: orange, by: t * 2) : orange.mix(with: yellow, by: (t - 0.5) * 2)
    }

    /// The navy-to-plum backdrop every wallpaper in the collection sits on.
    static func backdrop(in graphics: inout GraphicsContext, size: CGSize) {
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [navy, plum]),
            startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)
        ))
    }

    static func grain(amount: Float = 0.03) -> Shader {
        ShaderLibrary.grain(.float(amount))
    }
}
