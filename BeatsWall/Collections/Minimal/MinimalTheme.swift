//
//  MinimalTheme.swift
//  BeatsWall
//

import SwiftUI

/// Calm and clean: soft pastels, simple geometry, no clutter.
enum MinimalTheme {
    static let paper = Color(hex: 0xF5F1EA)
    static let paperShade = Color(hex: 0xEAE3D8)
    static let ink = Color(hex: 0x1E2128)
    static let slate = Color(hex: 0x24272F)
    static let peach = Color(hex: 0xF4A99B)
    static let sage = Color(hex: 0xA8C3A0)
    static let sky = Color(hex: 0x9CC3E6)
    static let lilac = Color(hex: 0xC3B1E1)
    static let butter = Color(hex: 0xF6D98B)
    static let coral = Color(hex: 0xF28482)

    static let palette = [peach, butter, sage, sky, lilac, coral]

    /// A color smoothly interpolated across the palette, t in 0...1.
    static func blend(_ t: Double) -> Color {
        let scaled = min(max(t, 0), 1) * Double(palette.count - 1)
        let index = min(Int(scaled), palette.count - 2)
        return palette[index].mix(with: palette[index + 1], by: scaled - Double(index))
    }

    /// Barely-there dithering so big smooth gradients don't band.
    static func dither() -> Shader {
        ShaderLibrary.grain(.float(0.012))
    }

    /// Average energy of `bands` equal slices of the spectrum.
    static func band(_ index: Int, of bands: Int, in spectrum: [Float]) -> Double {
        let size = max(spectrum.count / bands, 1)
        let start = min(index * size, spectrum.count - size)
        return Double(spectrum[start..<(start + size)].reduce(0, +)) / Double(size)
    }
}
