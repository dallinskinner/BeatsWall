//
//  RippleGridWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RippleGridWallpaper: View {
    let context: WallpaperContext
    @State private var clock = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(BrandTheme.grain(amount: 0.025))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let phase = clock.advance(to: frame.time, speed: 0.6 + 3.5 * Double(audio.mid))
        let pulse = Double(audio.beatPulse)
        let rect = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDistance = hypot(size.width, size.height) / 2

        BrandTheme.backdrop(in: &graphics, size: rect.size)

        // Dot grid. A ripple travels outward with the melody; a ring blooms out on each beat.
        let spacing = max(size.width, size.height) / 34
        let ringRadius = (1 - pulse) * maxDistance
        let columns = Int(size.width / spacing) + 2
        let rows = Int(size.height / spacing) + 2
        let offsetX = (size.width - CGFloat(columns - 1) * spacing) / 2
        let offsetY = (size.height - CGFloat(rows - 1) * spacing) / 2

        for row in 0..<rows {
            for column in 0..<columns {
                let base = CGPoint(x: offsetX + CGFloat(column) * spacing, y: offsetY + CGFloat(row) * spacing)
                let dx = base.x - center.x, dy = base.y - center.y
                let distance = max(hypot(dx, dy), 0.001)
                let wave = 0.5 + 0.5 * sin(distance / maxDistance * 14 - phase)
                let ring = exp(-pow((distance - ringRadius) / (spacing * 1.6), 2)) * pulse
                let brightness = min(1, 0.05 + 0.25 * wave * (0.3 + Double(audio.level)) + 0.85 * ring)
                // Magenta in the middle, warming to yellow at the edges.
                let tint = BrandTheme.gradient(Double(distance / maxDistance) * 1.2)

                let push = spacing * 0.6 * ring
                let point = CGPoint(x: base.x + dx / distance * push, y: base.y + dy / distance * push)
                let radius = spacing * 0.07 * (1 + 1.6 * brightness)

                if brightness > 0.12 {
                    let glow = radius * 4
                    graphics.fill(
                        Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)),
                        with: .radialGradient(
                            Gradient(colors: [tint.opacity(brightness * brightness * 0.5), .clear]),
                            center: point, startRadius: 0, endRadius: glow
                        )
                    )
                }
                graphics.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(BrandTheme.glow.mix(with: tint, by: brightness).opacity(0.2 + 0.8 * brightness))
                )
            }
        }

        // Three orbs in the icon's colors, pulsing in sequence and swelling with the bass.
        let unit = min(size.width, size.height)
        for index in 0..<3 {
            let color = BrandTheme.gradient(Double(index) / 2)
            let sequence = 0.5 + 0.5 * sin(phase * 1.2 - Double(index) * 0.9)
            let radius = unit * 0.022 * (1 + 0.5 * sequence + 0.6 * Double(audio.bass))
            let point = CGPoint(x: center.x + CGFloat(index - 1) * unit * 0.075, y: center.y)
            let glow = radius * 3.5
            graphics.fill(
                Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.25 + 0.35 * sequence), .clear]),
                    center: point, startRadius: 0, endRadius: glow
                )
            )
            graphics.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.mix(with: BrandTheme.glow, by: 0.35 * sequence))
            )
        }
    }
}
