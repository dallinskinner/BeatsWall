//
//  SkateTheme.swift
//  BeatsWall
//

import SwiftUI

/// Deck-graphic palette: bold flat colors with thick ink outlines.
enum SkateTheme {
    static let ink = Color(hex: 0x161616)
    static let offWhite = Color(hex: 0xF4EFE6)
    static let orange = Color(hex: 0xFF5A1F)
    static let teal = Color(hex: 0x2EC4B6)
    static let yellow = Color(hex: 0xFFD23F)
    static let pink = Color(hex: 0xFF6B9A)
    static let denim = Color(hex: 0x2B3A55)
    static let skin = Color(hex: 0xF2C29B)
    static let wood = Color(hex: 0xE8C07D)
    static let woodShade = Color(hex: 0xC99A55)
    static let steel = Color(hex: 0xB9C0C9)
    static let concrete = Color(hex: 0xD9D2C5)
    static let concreteShade = Color(hex: 0xB8AF9F)

    static func outline(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

extension GraphicsContext {
    /// Fills a path and strokes it with an ink outline, sticker-style.
    func fillOutlined(_ path: Path, _ color: Color, outline: CGFloat, ink: Color = SkateTheme.ink) {
        fill(path, with: .color(color))
        stroke(path, with: .color(ink), style: SkateTheme.outline(outline))
    }
}
