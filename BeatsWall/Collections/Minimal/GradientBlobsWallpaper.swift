//
//  GradientBlobsWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct GradientBlobsWallpaper: View {
    let context: WallpaperContext
    @State private var drift = PhaseClock()

    private static let blobs = [MinimalTheme.coral, MinimalTheme.butter, MinimalTheme.sky, MinimalTheme.lilac, MinimalTheme.sage]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(MinimalTheme.dither())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let phase = drift.advance(to: frame.time, speed: 0.08 + 0.2 * Double(audio.mid))
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xF7F2EE)))

        // Big soft blobs wandering on slow Lissajous paths and melting into each other.
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.14))
            for (index, color) in Self.blobs.enumerated() {
                let a = 0.7 + 0.25 * Double(index)
                let b = 0.9 + 0.17 * Double(index)
                let center = CGPoint(
                    x: size.width * CGFloat(0.5 + 0.32 * sin(phase * a + Double(index) * 1.7)),
                    y: size.height * CGFloat(0.5 + 0.3 * cos(phase * b + Double(index) * 2.3))
                )
                let energy = MinimalTheme.band(index, of: Self.blobs.count, in: audio.spectrum)
                let radius = unit * CGFloat(0.22 + 0.08 * energy) * (1 + 0.06 * CGFloat(audio.beatPulse))
                layer.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color.opacity(0.85)))
            }
        }
    }
}
