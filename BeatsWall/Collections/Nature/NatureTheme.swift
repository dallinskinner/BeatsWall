//
//  NatureTheme.swift
//  BeatsWall
//

import SwiftUI

enum NatureTheme {
    static let night = Color(hex: 0x0B1D3A)
    static let nightSky = Color(hex: 0x24496B)
    static let farWater = Color(hex: 0x2A5A85)
    static let nearWater = Color(hex: 0x0B2340)
    static let foam = Color(hex: 0xE8F4F2)
    static let moon = Color(hex: 0xF4EBC8)
    static let duskTop = Color(hex: 0x1B2A4A)
    static let duskMid = Color(hex: 0x6B4C7A)
    static let duskGlow = Color(hex: 0xE07A5F)
    static let grass = Color(hex: 0x0F1A14)
    static let firefly = Color(hex: 0xD7F75B)
    static let glass = Color(hex: 0x0E1A2B)

    static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func glow(in graphics: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        graphics.fill(disc(center, radius), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }
}
