//
//  BeatBWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// The BeatsWall B, built from equalizer bars: each row's last bar stretches with its slice of
/// the spectrum, and the whole letter flares on the kick.
struct BeatBWallpaper: View {
    let context: WallpaperContext

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(BrandTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let pulse = Double(audio.beatPulse)
        let bass = Double(audio.bass)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        BrandTheme.backdrop(in: &graphics, size: size)
        var light = graphics
        light.blendMode = .plusLighter

        // Bass halo, and rings rippling out from the letter on each beat.
        let halo = unit * CGFloat(0.45 + 0.25 * bass)
        light.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .radialGradient(
            Gradient(colors: [BrandTheme.magenta.opacity(0.18 + 0.3 * bass), BrandTheme.magenta.opacity(0)]),
            center: center, startRadius: 0, endRadius: halo
        ))
        let beat = audio.beatProgress(at: frame.time)
        for ring in 0..<4 {
            let phase = (Double(ring) + beat.truncatingRemainder(dividingBy: 1)) / 4
            let radius = unit * CGFloat(0.3 + 0.55 * phase)
            light.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(BrandTheme.gradient(phase).opacity(0.3 * (1 - phase))),
                lineWidth: unit * 0.004
            )
        }

        // The letter, a little bigger on the kick.
        let width = unit * 0.25 * CGFloat(1 + 0.05 * pulse)
        let scale = width / 6.6
        let rowHeight = scale * 2.2
        let barHeight = scale * 1.7
        let rows = BeatsWallLogo.rows
        let origin = CGPoint(x: center.x - width / 2 - scale * 0.6, y: center.y - rowHeight * CGFloat(rows.count) / 2)
        // The rows' last bars reach right like an equalizer: low end at the bottom.
        func reach(_ row: Int) -> CGFloat {
            let bin = min((rows.count - 1 - row) * 4 + 1, AudioFeatures.binCount - 1)
            return scale * 2.4 * CGFloat(audio.spectrum[bin])
        }
        func bars(grow: CGFloat) -> Path {
            var path = Path()
            for (row, segments) in rows.enumerated() {
                for (index, segment) in segments.enumerated() {
                    let end = segment.end + (index == segments.count - 1 ? reach(row) / scale : 0)
                    let rect = CGRect(
                        x: origin.x + segment.start * scale,
                        y: origin.y + CGFloat(row) * rowHeight,
                        width: (end - segment.start) * scale,
                        height: barHeight
                    ).insetBy(dx: -grow, dy: -grow)
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.height / 2, height: rect.height / 2))
                }
            }
            return path
        }
        let span = (origin.x, origin.x + scale * 9)
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [BrandTheme.magenta, BrandTheme.orange, BrandTheme.yellow]),
            startPoint: CGPoint(x: span.0, y: center.y), endPoint: CGPoint(x: span.1, y: center.y)
        )

        // An echo of the letter that expands and fades after each beat.
        var echo = light
        echo.translateBy(x: center.x, y: center.y)
        echo.scaleBy(x: 1 + 0.5 * (1 - pulse), y: 1 + 0.5 * (1 - pulse))
        echo.translateBy(x: -center.x, y: -center.y)
        echo.stroke(bars(grow: 0), with: .color(BrandTheme.magenta.opacity(0.5 * pulse)), lineWidth: scale * 0.15)

        graphics.drawLayer { layer in
            layer.addFilter(.shadow(color: BrandTheme.magenta.opacity(0.5 + 0.4 * bass), radius: unit * CGFloat(0.015 + 0.04 * bass)))
            layer.fill(bars(grow: 0), with: shading)
        }
        // A bright sheen across the top of every bar.
        var sheen = Path()
        for (row, segments) in rows.enumerated() {
            for (index, segment) in segments.enumerated() {
                let end = segment.end + (index == segments.count - 1 ? reach(row) / scale : 0)
                sheen.addRoundedRect(
                    in: CGRect(x: origin.x + (segment.start + 0.2) * scale, y: origin.y + CGFloat(row) * rowHeight + barHeight * 0.15, width: max((end - segment.start - 0.4) * scale, 0), height: barHeight * 0.22),
                    cornerSize: CGSize(width: barHeight * 0.1, height: barHeight * 0.1)
                )
            }
        }
        light.fill(sheen, with: .color(.white.opacity(0.18 + 0.2 * pulse)))
    }
}
