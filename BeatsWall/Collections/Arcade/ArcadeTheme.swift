//
//  ArcadeTheme.swift
//  BeatsWall
//

import SwiftUI

/// Chunky pixel art on a CRT.
enum ArcadeTheme {
    static let black = Color(hex: 0x0B0B1A)
    static let mazeBlue = Color(hex: 0x2E5BFF)
    static let mazeFill = Color(hex: 0x111A4A)
    static let yellow = Color(hex: 0xFFE14D)
    static let red = Color(hex: 0xFF4D6D)
    static let pink = Color(hex: 0xFF8AD8)
    static let cyan = Color(hex: 0x4DF3FF)
    static let orange = Color(hex: 0xFFA24D)
    static let green = Color(hex: 0x6BFF8A)
    static let white = Color(hex: 0xF4F4FF)
    static let dot = Color(hex: 0xFFD9B3)

    /// Pixel size so the screen is roughly `across` pixels on its short side.
    static func pixel(for size: CGSize, across: CGFloat) -> CGFloat {
        max(2, (min(size.width, size.height) / across).rounded(.down))
    }

    static func snap(_ value: CGFloat, to pixel: CGFloat) -> CGFloat {
        (value / pixel).rounded() * pixel
    }

    static func crt(time: Double, pixel: CGFloat) -> Shader {
        ShaderLibrary.scanlines(.float(time), .float(0.22), .float(max(2, pixel)))
    }

    /// Draws multi-color pixel art: each character maps to a color, `.`/space is transparent.
    static func drawSprite(_ rows: [String], palette: [Character: Color], origin: CGPoint, pixel: CGFloat, in graphics: GraphicsContext, flipped: Bool = false) {
        var paths: [Character: Path] = [:]
        let width = rows.map(\.count).max() ?? 0
        for (row, line) in rows.enumerated() {
            for (column, character) in line.enumerated() where palette[character] != nil {
                let x = flipped ? width - 1 - column : column
                paths[character, default: Path()].addRect(CGRect(
                    x: origin.x + CGFloat(x) * pixel, y: origin.y + CGFloat(row) * pixel,
                    width: pixel + 0.5, height: pixel + 0.5
                ))
            }
        }
        for (character, path) in paths {
            graphics.fill(path, with: .color(palette[character]!))
        }
    }

    /// Small pixel bugs used as enemies across the collection. Two frames each.
    static let bugA = [
        ["...##...", "..####..", ".##..##.", "########", "#.####.#", "..#..#..", ".#.##.#.", "#......#"],
        ["...##...", "..####..", ".##..##.", "########", "#.####.#", "..#..#..", ".#....#.", "..#..#.."],
    ]
    static let bugB = [
        ["..#..#..", "...##...", ".######.", "##.##.##", "########", ".#.##.#.", "#......#", ".#....#."],
        ["..#..#..", "#..##..#", "#######.", "##.##.##", "########", "..####..", ".#.##.#.", "#.#..#.#"],
    ]
}
