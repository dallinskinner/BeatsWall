//
//  RingedPlanetWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RingedPlanetWallpaper: View {
    let context: WallpaperContext
    @State private var orbit = PhaseClock()

    private static let tilt = -0.32
    private static let flatten: CGFloat = 0.28
    private static let ringCount = 26
    private static let ringColors = [Color(hex: 0xE8C9A0), Color(hex: 0xC9A27E), Color(hex: 0xF2E3C6), Color(hex: 0xB08968)]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = unit * 0.17
        // Moons complete an orbit every 16 beats.
        let angle = orbit.advance(to: frame.time, speed: 2 * .pi / (16 * audio.beatLength))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [SpaceTheme.deep, SpaceTheme.void]),
            center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
        ))
        SpaceTheme.drawStars(in: &graphics, size: size, count: 200, audio: audio, time: frame.time)

        let moons: [(distance: CGFloat, size: CGFloat, offset: Double, color: Color)] = [
            (2.7, 0.13, 0, Color(hex: 0xBFC6D1)),
            (3.4, 0.08, 2.4, Color(hex: 0xD9A27E)),
        ]
        func drawMoons(far: Bool) {
            for moon in moons {
                let theta = angle * (moon.distance < 3 ? 1 : 0.7) + moon.offset
                guard (sin(theta) < 0) == far else { continue }
                let local = CGPoint(x: cos(theta) * moon.distance * radius, y: sin(theta) * moon.distance * radius * Self.flatten)
                let position = center + rotate(local, by: Self.tilt)
                let r = radius * moon.size
                let rect = CGRect(x: position.x - r, y: position.y - r, width: r * 2, height: r * 2)
                graphics.fill(Path(ellipseIn: rect), with: .color(moon.color))
                graphics.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.75)]),
                    center: position + CGPoint(x: -r * 0.5, y: -r * 0.5), startRadius: r * 0.3, endRadius: r * 2
                ))
            }
        }

        drawMoons(far: true)
        drawRings(in: graphics, center: center, radius: radius, unit: unit, audio: audio, front: false)
        drawPlanet(in: &graphics, center: center, radius: radius, frame: frame)
        drawRings(in: graphics, center: center, radius: radius, unit: unit, audio: audio, front: true)
        drawMoons(far: false)
    }

    private func drawPlanet(in graphics: inout GraphicsContext, center: CGPoint, radius: CGFloat, frame: AudioFrame) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        let glow = radius * 1.25
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(Gradient(colors: [Color(hex: 0xF2B880).opacity(0.25), .clear]), center: center, startRadius: radius * 0.95, endRadius: glow)
        )

        var surface = graphics
        surface.clip(to: disc)
        surface.fill(disc, with: .color(Color(hex: 0xD9A066)))
        surface.translateBy(x: center.x, y: center.y)
        surface.rotate(by: .radians(Self.tilt))
        let bands: [(y: CGFloat, height: CGFloat, color: Color)] = [
            (-0.85, 0.2, Color(hex: 0xE8C9A0)), (-0.55, 0.12, Color(hex: 0xB86F45)), (-0.3, 0.18, Color(hex: 0xF2D2A9)),
            (0.0, 0.1, Color(hex: 0xA65A3A)), (0.2, 0.22, Color(hex: 0xE5B585)), (0.5, 0.1, Color(hex: 0xB86F45)), (0.72, 0.18, Color(hex: 0xEED3B0)),
        ]
        for (index, band) in bands.enumerated() {
            var path = Path()
            let top = band.y * radius
            path.move(to: CGPoint(x: -radius * 1.2, y: top))
            for step in 0...24 {
                let x = -radius * 1.2 + radius * 2.4 * CGFloat(step) / 24
                path.addLine(to: CGPoint(x: x, y: top + radius * 0.025 * CGFloat(sin(Double(step) * 0.8 + frame.time * 0.3 + Double(index)))))
            }
            path.addLine(to: CGPoint(x: radius * 1.2, y: top + band.height * radius))
            path.addLine(to: CGPoint(x: -radius * 1.2, y: top + band.height * radius))
            path.closeSubpath()
            surface.fill(path, with: .color(band.color))
        }
        // Light from the upper left.
        graphics.fill(disc, with: .radialGradient(
            Gradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.75)]),
            center: center + CGPoint(x: -radius * 0.45, y: -radius * 0.45), startRadius: 0, endRadius: radius * 2.1
        ))
    }

    private func drawRings(in graphics: GraphicsContext, center: CGPoint, radius: CGFloat, unit: CGFloat, audio: AudioFeatures, front: Bool) {
        var rings = graphics
        rings.translateBy(x: center.x, y: center.y)
        rings.rotate(by: .radians(Self.tilt))
        // Far half of the rings is behind the planet, near half in front.
        rings.clip(to: Path(CGRect(x: -unit * 2, y: front ? 0 : -unit * 2, width: unit * 4, height: unit * 2)))
        rings.scaleBy(x: 1, y: Self.flatten)

        let wave = 1 - Double(audio.beatPulse)
        for index in 0..<Self.ringCount {
            let t = Double(index) / Double(Self.ringCount - 1)
            let bin = min(3 + index, AudioFeatures.binCount - 1)
            let energy = Double(audio.spectrum[bin])
            // Rings ripple outward with the spectrum; a shimmer travels across them on each beat.
            let r = radius * CGFloat(1.35 + 1.0 * t) + unit * 0.01 * CGFloat(energy)
            let shimmer = exp(-pow((t - wave) / 0.08, 2)) * Double(audio.beatPulse)
            let opacity = min(1, 0.18 + 0.45 * energy + 0.5 * shimmer) * (index % 7 == 4 ? 0.25 : 1)
            let color = Self.ringColors[index % Self.ringColors.count]
            rings.stroke(
                Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
                with: .color(color.opacity(opacity)),
                lineWidth: radius * 0.035
            )
        }
    }

    private func rotate(_ point: CGPoint, by angle: Double) -> CGPoint {
        CGPoint(x: point.x * cos(angle) - point.y * sin(angle), y: point.x * sin(angle) + point.y * cos(angle))
    }
}
