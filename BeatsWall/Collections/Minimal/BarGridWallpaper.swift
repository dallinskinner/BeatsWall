//
//  BarGridWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct BarGridWallpaper: View {
    let context: WallpaperContext

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
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MinimalTheme.slate))

        // A faint dot grid.
        var dots = Path()
        let spacing = unit * 0.05
        var y = (size.height.truncatingRemainder(dividingBy: spacing)) / 2
        while y < size.height {
            var x = (size.width.truncatingRemainder(dividingBy: spacing)) / 2
            while x < size.width {
                dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                x += spacing
            }
            y += spacing
        }
        graphics.fill(dots, with: .color(.white.opacity(0.06)))

        // Mirrored rounded bars, one per spectrum bin.
        let count = AudioFeatures.binCount
        let total = min(size.width * 0.72, unit * 1.3)
        let pitch = total / CGFloat(count)
        let barWidth = pitch * 0.55
        let maxHeight = unit * 0.26
        for bin in 0..<count {
            let energy = CGFloat(audio.spectrum[bin])
            let height = max(barWidth, maxHeight * (0.04 + 0.96 * energy))
            let x = center.x - total / 2 + pitch * (CGFloat(bin) + 0.5) - barWidth / 2
            let rect = CGRect(x: x, y: center.y - height, width: barWidth, height: height * 2)
            let color = MinimalTheme.blend(Double(bin) / Double(count - 1))
            graphics.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color.opacity(0.55 + 0.45 * Double(energy))))
        }

        // Four dots marking the beat within the bar.
        let step = audio.beatCount % 4
        for index in 0..<4 {
            let r = unit * 0.006
            let point = CGPoint(x: center.x + (CGFloat(index) - 1.5) * unit * 0.03, y: center.y + maxHeight + unit * 0.08)
            let active = index == step
            graphics.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(active ? 0.4 + 0.5 * Double(audio.beatPulse) : 0.12)))
        }
    }
}
