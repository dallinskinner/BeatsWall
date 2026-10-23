//
//  CanopyWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct CanopyWallpaper: View {
    let context: WallpaperContext
    @State private var breeze = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(JungleTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let wind = breeze.advance(to: frame.time, speed: 0.6 + 1.4 * Double(audio.mid))
        let swayAmount = 0.04 + 0.1 * Double(audio.mid)

        // Bright, misty depths behind everything.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xBFE3A8), JungleTheme.leafLight, JungleTheme.mid]),
            center: CGPoint(x: size.width * 0.55, y: size.height * 0.35), startRadius: 0, endRadius: max(size.width, size.height) * 0.7
        ))
        var light = graphics
        light.blendMode = .plusLighter
        for index in 0..<5 {
            let x = size.width * CGFloat(0.2 + 0.15 * Double(index))
            var ray = Path()
            ray.addLines([CGPoint(x: x, y: 0), CGPoint(x: x + unit * 0.06, y: 0), CGPoint(x: x + unit * 0.3, y: size.height), CGPoint(x: x + unit * 0.16, y: size.height)])
            ray.closeSubpath()
            light.fill(ray, with: .linearGradient(Gradient(colors: [JungleTheme.sun.opacity(0.18), .clear]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x, y: size.height)))
        }

        // Layers of leaves, far (pale, small) to near (dark, huge).
        let layers: [(color: Color, count: Int, size: CGFloat)] = [
            (Color(hex: 0x5FAF6A), 10, 0.18), (JungleTheme.leaf, 9, 0.26), (JungleTheme.mid, 7, 0.36), (JungleTheme.shade, 6, 0.5),
        ]
        for (layer, spec) in layers.enumerated() {
            var leaves = Path()
            var slits = Path()
            var stems = Path()
            for index in 0..<spec.count {
                let seed = layer * 40 + index
                // Leaves hang in from the edges and top.
                let edge = Int(hash01(seed, 1) * 4)
                let along = CGFloat(hash01(seed, 2))
                let base: CGPoint
                let baseAngle: Double
                switch edge {
                case 0: base = CGPoint(x: along * size.width, y: -unit * 0.05); baseAngle = .pi / 2 + (hash01(seed, 3) - 0.5) * 1.2
                case 1: base = CGPoint(x: -unit * 0.05, y: along * size.height); baseAngle = (hash01(seed, 3) - 0.6) * 1.0
                case 2: base = CGPoint(x: size.width + unit * 0.05, y: along * size.height); baseAngle = .pi + (0.6 - hash01(seed, 3)) * 1.0
                default: base = CGPoint(x: along * size.width, y: size.height + unit * 0.05); baseAngle = -.pi / 2 + (hash01(seed, 3) - 0.5) * 1.2
                }
                let angle = baseAngle + sin(wind + Double(seed)) * swayAmount * (1 + Double(layer) * 0.3)
                let length = unit * spec.size * CGFloat(0.7 + 0.5 * hash01(seed, 4))
                if hash01(seed, 5) > 0.4 {
                    let (leaf, stem) = JungleTheme.monstera(base: base, angle: angle, length: length)
                    leaves.addPath(leaf)
                    stems.addPath(stem)
                    slits.addPath(JungleTheme.monsteraSlits(base: base, angle: angle, length: length))
                } else {
                    leaves.addPath(JungleTheme.frond(base: base, angle: angle, length: length * 1.3, droop: length * 0.25))
                }
            }
            graphics.stroke(stems, with: .color(spec.color), lineWidth: unit * 0.006)
            let leafLayer = graphics
            leafLayer.drawLayer { context in
                context.fill(leaves, with: .color(spec.color))
                context.blendMode = .destinationOut
                context.fill(slits, with: .color(.black))
            }
            // Mist between layers.
            if layer < 3 {
                graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(JungleTheme.mist.opacity(0.06)))
            }
        }

        // Sun dapples flickering through the canopy with the hi-hats.
        for index in 0..<18 {
            let flicker = 0.5 + 0.5 * sin(frame.time * (2 + 3 * hash01(index, 8)) + Double(index))
            let brightness = flicker * (0.3 + 0.7 * Double(audio.treble))
            let point = CGPoint(x: CGFloat(hash01(index, 6)) * size.width + unit * 0.02 * CGFloat(sin(wind + Double(index))), y: CGFloat(hash01(index, 7)) * size.height)
            JungleTheme.glow(in: light, at: point, radius: unit * CGFloat(0.02 + 0.03 * hash01(index, 9)), color: JungleTheme.sun, opacity: 0.35 * brightness)
        }
    }
}
