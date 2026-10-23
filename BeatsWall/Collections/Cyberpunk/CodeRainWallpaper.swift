//
//  CodeRainWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct CodeRainWallpaper: View {
    let context: WallpaperContext
    @State private var fall = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
            .colorEffect(ShaderLibrary.scanlines(.float(frame.time), .float(0.12), .float(3)))
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let phase = fall.advance(to: frame.time, speed: 0.6 + 1.6 * Double(audio.level))
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(CyberTheme.black))

        let pixel = max(1, (unit / (context.isPreview ? 260 : 300)).rounded(.down))
        let cell = CGSize(width: pixel * 7, height: pixel * 9)
        let columns = Int(size.width / cell.width) + 1
        let rows = Int(size.height / cell.height) + 1
        let trail = 16
        // Brightness buckets so thousands of glyph pixels draw in a few fills.
        var buckets = [Path](repeating: Path(), count: 5)
        var heads = Path()
        var flares = Path()

        for column in 0..<columns {
            let speed = 6 + 10 * hash01(column, 1)
            let length = rows + trail + Int(hash01(column, 2) * Double(rows))
            let head = Int((hash01(column, 3) * Double(length) + phase * speed).rounded(.down)) % length
            let flaring = hash01(column, audio.beatCount) > 0.82 && audio.beatPulse > 0.2
            for back in 0..<trail {
                let row = head - back
                guard row >= 0, row < rows else { continue }
                // Glyphs mutate over time.
                let glyph = CyberTheme.glyphs[Int(hash01(column * 131 + row, Int(frame.time * 3) + column) * Double(CyberTheme.glyphs.count))]
                let origin = CGPoint(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height)
                if back == 0 {
                    heads.addPixelSprite(glyph, origin: origin, pixelWidth: pixel)
                } else if flaring && back < 6 {
                    flares.addPixelSprite(glyph, origin: origin, pixelWidth: pixel)
                } else {
                    buckets[min(back * 5 / trail, 4)].addPixelSprite(glyph, origin: origin, pixelWidth: pixel)
                }
            }
        }
        for (index, bucket) in buckets.enumerated() {
            graphics.fill(bucket, with: .color(CyberTheme.toxic.opacity(0.9 - 0.18 * Double(index))))
        }
        graphics.fill(flares, with: .color(CyberTheme.toxic.mix(with: .white, by: 0.6)))
        var glow = graphics
        glow.addFilter(.shadow(color: CyberTheme.toxic, radius: pixel * 3))
        glow.fill(heads, with: .color(.white))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.6)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: unit * 0.3, endRadius: max(size.width, size.height) * 0.75
        ))
    }
}
