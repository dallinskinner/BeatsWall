//
//  BreathingRingsWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct BreathingRingsWallpaper: View {
    let context: WallpaperContext
    @State private var spin = PhaseClock()

    private static let rings = 12

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
        let rotation = spin.advance(to: frame.time, speed: 0.05 + 0.25 * Double(audio.mid))
        let breathe = 1 + 0.025 * CGFloat(audio.beatPulse) + 0.02 * CGFloat(sin(frame.time * 0.5))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [MinimalTheme.paper, MinimalTheme.paperShade]),
            center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
        ))

        // Soft core that swells with overall loudness.
        let core = unit * 0.04 * (1 + 0.6 * CGFloat(audio.level)) * breathe
        graphics.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)), with: .radialGradient(
            Gradient(colors: [MinimalTheme.peach, MinimalTheme.peach.opacity(0.3)]),
            center: center, startRadius: 0, endRadius: core
        ))

        // Each ring is one slice of the spectrum, low in the middle, highs outside.
        for ring in 0..<Self.rings {
            let t = Double(ring) / Double(Self.rings - 1)
            let energy = MinimalTheme.band(ring, of: Self.rings, in: audio.spectrum)
            let radius = (unit * CGFloat(0.075 + 0.032 * Double(ring)) + unit * 0.012 * CGFloat(energy)) * breathe
            let width = unit * CGFloat(0.003 + 0.009 * energy)
            let color = MinimalTheme.blend(t)
            let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if ring % 3 == 1 {
                // Dashed rings slowly turning, in opposite directions.
                let circumference = 2 * .pi * radius
                let dash = circumference / CGFloat(24 + ring * 2)
                let direction: Double = ring % 2 == 0 ? 1 : -1
                graphics.stroke(circle, with: .color(color.opacity(0.45 + 0.55 * energy)), style: StrokeStyle(
                    lineWidth: width, lineCap: .round, dash: [dash * 0.35, dash * 0.65],
                    dashPhase: CGFloat(rotation * direction) * radius * 0.6
                ))
            } else {
                graphics.stroke(circle, with: .color(color.opacity(0.35 + 0.65 * energy)), lineWidth: width)
            }
        }
    }
}
