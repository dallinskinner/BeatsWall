//
//  CyberTheme.swift
//  BeatsWall
//

import SwiftUI

/// Harsh neon on black.
enum CyberTheme {
    static let black = Color(hex: 0x05050A)
    static let panel = Color(hex: 0x0D0D18)
    static let tower = Color(hex: 0x120F22)
    static let magenta = Color(hex: 0xFF2BD6)
    static let cyan = Color(hex: 0x00F0FF)
    static let acid = Color(hex: 0xF5FF3B)
    static let toxic = Color(hex: 0x39FF88)
    static let red = Color(hex: 0xFF3355)

    static let neons = [magenta, cyan, acid, toxic, red]

    /// 24 invented 5×7 glyphs, so the code rain isn't any real alphabet.
    static let glyphs: [[String]] = (0..<24).map { seed in
        (0..<7).map { row in
            String((0..<5).map { column -> Character in
                // A spine down one column keeps glyphs looking like characters, not noise.
                if column == 1 + seed % 3, row > 0, row < 6 { return "#" }
                return hash01(seed * 37 + row, column) < 0.38 ? "#" : "."
            })
        }
    }
}
