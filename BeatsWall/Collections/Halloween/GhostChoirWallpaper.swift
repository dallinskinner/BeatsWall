//
//  GhostChoirWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct GhostChoirWallpaper: View {
    let context: WallpaperContext
    @State private var float = PhaseClock()

    private static let voices = 5
    private static let wisp = Color(hex: 0x8CFFE0)

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(HalloweenTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let ground = size.height * 0.82
        let phase = float.advance(to: frame.time, speed: 0.8 + 1.5 * Double(audio.mid))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [HalloweenTheme.midnight, Color(hex: 0x1A2333), Color(hex: 0x3A4658)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: ground)
        ))
        HalloweenTheme.drawMoon(in: &graphics, center: CGPoint(x: size.width * 0.5, y: size.height * 0.16), radius: unit * 0.055, brightness: 0.2)

        // Forest layers fading into the mist; ghosts float among the middle rows.
        for layer in 0..<4 {
            drawTrees(in: &graphics, size: size, unit: unit, ground: ground, layer: layer)
            if layer == 2 {
                drawGhosts(in: &graphics, size: size, unit: unit, frame: frame, phase: phase)
            }
            if layer < 3 {
                graphics.fill(Path(CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.65)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x5A6478).opacity(0), Color(hex: 0x5A6478).opacity(0.22)]),
                    startPoint: CGPoint(x: 0, y: size.height * 0.35), endPoint: CGPoint(x: 0, y: ground)
                ))
            }
        }
        graphics.fill(Path(CGRect(x: 0, y: ground, width: size.width, height: size.height)), with: .color(HalloweenTheme.silhouette))

        // Will-o'-wisps.
        var light = graphics
        light.blendMode = .plusLighter
        for index in 0..<14 {
            let t = frame.time * (0.05 + 0.05 * hash01(index, 41))
            let point = CGPoint(
                x: size.width * CGFloat(hash01(index, 42)) + unit * 0.1 * CGFloat(sin(t * 3 + Double(index))),
                y: size.height * CGFloat(0.45 + 0.4 * hash01(index, 43)) + unit * 0.04 * CGFloat(sin(t * 5 + Double(index) * 2))
            )
            let flicker = 0.5 + 0.5 * sin(frame.time * (2 + 3 * hash01(index, 44)) + Double(index))
            let brightness = 0.2 + 0.6 * flicker * (0.5 + Double(audio.treble))
            HalloweenTheme.glow(in: light, at: point, radius: unit * 0.025, color: Self.wisp, opacity: 0.45 * brightness)
            light.fill(HalloweenTheme.disc(point, unit * 0.003), with: .color(Self.wisp.opacity(brightness)))
        }

        HalloweenTheme.drawFog(in: &graphics, size: size, top: ground - unit * 0.1, drift: phase * 0.03, density: 0.7, tint: Color(hex: 0x9AA6B8))
    }

    private func drawTrees(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, ground: CGFloat, layer: Int) {
        let depth = Double(layer) / 3
        let color = Color(hex: 0x4A5468).mix(with: HalloweenTheme.silhouette, by: 0.35 + 0.65 * depth)
        let count = 16 - layer * 3
        var trunks = Path()
        var branches = Path()
        for index in 0..<count {
            let seed = layer * 100 + index
            let x = size.width * CGFloat((Double(index) + hash01(seed, 1)) / Double(count))
            let width = unit * CGFloat(0.006 + 0.012 * depth) * CGFloat(0.7 + 0.6 * hash01(seed, 2))
            let base = ground - unit * CGFloat(0.06 * (1 - depth))
            let lean = CGFloat(hash01(seed, 3) - 0.5) * unit * 0.04
            trunks.addLines([CGPoint(x: x - width, y: base), CGPoint(x: x - width * 0.4 + lean, y: -unit * 0.05), CGPoint(x: x + width * 0.4 + lean, y: -unit * 0.05), CGPoint(x: x + width, y: base)])
            trunks.closeSubpath()
            for branch in 0..<3 {
                let y = base - (base + unit * 0.05) * CGFloat(0.35 + 0.2 * Double(branch) + 0.1 * hash01(seed, 10 + branch))
                let side: CGFloat = (branch + index) % 2 == 0 ? -1 : 1
                let along = (base - y) / (base + unit * 0.05)
                let start = CGPoint(x: x + lean * along, y: y)
                branches.move(to: start)
                let reach = unit * CGFloat(0.04 + 0.04 * hash01(seed, 20 + branch))
                let twig = start + CGPoint(x: side * reach, y: -reach * 0.9)
                branches.addLine(to: twig)
                branches.move(to: start + (twig - start) * 0.6)
                branches.addLine(to: twig + CGPoint(x: side * reach * 0.1, y: -reach * 0.55))
            }
        }
        graphics.fill(trunks, with: .color(color))
        graphics.stroke(branches, with: .color(color), style: StrokeStyle(lineWidth: max(1, unit * CGFloat(0.002 + 0.003 * depth)), lineCap: .round))
    }

    private func drawGhosts(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame, phase: Double) {
        let audio = frame.audio
        let bins = AudioFeatures.binCount / Self.voices
        let wail = audio.bass > 0.6 ? Double(audio.beatPulse) : 0
        var bodies: [(path: Path, face: Path)] = []

        for index in 0..<Self.voices {
            let width = unit * CGFloat(0.1 + 0.02 * hash01(index, 1))
            let height = width * 1.45
            let center = CGPoint(
                x: size.width * CGFloat(0.18 + 0.16 * Double(index)) + unit * 0.012 * CGFloat(sin(phase * 0.7 + Double(index))),
                y: size.height * CGFloat(0.52 + 0.05 * hash01(index, 2)) + unit * 0.025 * CGFloat(sin(phase * 1.1 + Double(index) * 1.3))
            )
            let top = center.y - height * 0.5
            let domeCenter = CGPoint(x: center.x, y: top + width / 2)
            let hemY = center.y + height * 0.5

            var body = Path()
            body.move(to: CGPoint(x: center.x - width * 0.56, y: hemY))
            body.addLine(to: CGPoint(x: center.x - width / 2, y: domeCenter.y))
            body.addArc(center: domeCenter, radius: width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            body.addLine(to: CGPoint(x: center.x + width * 0.56, y: hemY))
            // Wavy hem rippling as it floats.
            let scallops = 4
            for step in stride(from: scallops * 6, through: 0, by: -1) {
                let t = Double(step) / Double(scallops * 6)
                let x = center.x - width * 0.56 + width * 1.12 * CGFloat(t)
                let y = hemY + width * 0.08 * CGFloat(sin(t * Double(scallops) * 2 * .pi + phase * 2 + Double(index)))
                body.addLine(to: CGPoint(x: x, y: y))
            }
            body.closeSubpath()

            // Each ghost sings one band, low voices on the left; all wail together on big beats.
            let voice = Double(audio.spectrum[(index * bins)..<((index + 1) * bins)].reduce(0, +)) / Double(bins)
            let sing = max(0.15 + 0.85 * voice, wail)
            var face = Path()
            for side: CGFloat in [-1, 1] {
                face.addPath(HalloweenTheme.ellipse(domeCenter + CGPoint(x: side * width * 0.17, y: width * 0.02), width * 0.07, width * CGFloat(0.1 - 0.03 * sing)))
            }
            face.addPath(HalloweenTheme.ellipse(domeCenter + CGPoint(x: 0, y: width * 0.33), width * CGFloat(0.06 + 0.05 * sing), width * CGFloat(0.04 + 0.2 * sing)))
            bodies.append((body, face))
        }

        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.025))
            for ghost in bodies {
                layer.fill(ghost.path, with: .color(.white.opacity(0.25)))
            }
        }
        for ghost in bodies {
            let bounds = ghost.path.boundingRect
            graphics.fill(ghost.path, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.8), Color(hex: 0xC8D6E8).opacity(0.12)]),
                startPoint: CGPoint(x: bounds.midX, y: bounds.minY), endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
            ))
            graphics.fill(ghost.face, with: .color(Color(hex: 0x10131C).opacity(0.85)))
        }
    }
}
