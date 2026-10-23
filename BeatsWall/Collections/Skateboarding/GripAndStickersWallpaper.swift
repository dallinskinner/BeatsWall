//
//  GripAndStickersWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Top-down close-up of a deck covered in stickers.
struct GripAndStickersWallpaper: View {
    let context: WallpaperContext

    private enum Sticker: CaseIterable {
        case star, bolt, smiley, label, eye, flame, heart
    }

    /// Position (u along the deck, v across it, both -0.5...0.5), rotation and size (fraction of deck width).
    private static let layout: [(sticker: Sticker, u: CGFloat, v: CGFloat, rotation: Double, size: CGFloat)] = [
        (.smiley, -0.4, -0.05, -0.2, 0.3),
        (.bolt, -0.19, 0.18, 0.35, 0.3),
        (.label, -0.04, -0.17, -0.08, 0.26),
        (.star, 0.1, 0.17, 0.2, 0.3),
        (.eye, 0.19, -0.12, 0.1, 0.24),
        (.flame, 0.41, 0.06, -0.3, 0.3),
        (.heart, -0.07, 0.22, 0.25, 0.18),
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let length = min(size.width * 0.94, size.height * 2.7)
            let width = length * 0.27
            let unit = min(size.width, size.height)

            AudioTimeline(context: context) { frame in
                ZStack {
                    background(size: size, unit: unit)

                    ZStack {
                        Capsule()
                            .fill(SkateTheme.ink)
                            .frame(width: length + unit * 0.014, height: width + unit * 0.014)
                            .shadow(color: .black.opacity(0.35), radius: unit * 0.02, y: unit * 0.015)
                        Capsule()
                            .fill(.white)
                            .frame(width: length, height: width)
                            .colorEffect(ShaderLibrary.gripTape(
                                .float(max(1.2, unit * 0.0022)),
                                .float(frame.time),
                                .float(Double(frame.audio.treble))
                            ))
                        Canvas { graphics, deckSize in
                            drawDeck(in: &graphics, size: deckSize, frame: frame)
                        }
                        .frame(width: length, height: width)
                    }
                    .rotationEffect(.degrees(-8))
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    private func background(size: CGSize, unit: CGFloat) -> some View {
        Canvas { graphics, size in
            graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SkateTheme.offWhite))
            var stripes = Path()
            let spacing = unit * 0.05
            var x = -size.height
            while x < size.width {
                stripes.move(to: CGPoint(x: x, y: size.height))
                stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            graphics.stroke(stripes, with: .color(SkateTheme.teal.opacity(0.12)), lineWidth: spacing * 0.35)
        }
    }

    private func drawDeck(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let deckWidth = size.height

        // Truck bolts glow with the bass.
        for truck: CGFloat in [-0.3, 0.3] {
            for (du, dv) in [(-0.035, -0.17), (0.035, -0.17), (-0.035, 0.17), (0.035, 0.17)] {
                let point = center + CGPoint(x: (truck + du) * size.width, y: dv * deckWidth)
                let r = deckWidth * 0.032
                let glow = r * (2.5 + 2.5 * CGFloat(audio.bass))
                graphics.fill(
                    Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)),
                    with: .radialGradient(Gradient(colors: [SkateTheme.orange.opacity(0.55 * Double(audio.bass)), .clear]), center: point, startRadius: 0, endRadius: glow)
                )
                graphics.fillOutlined(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), SkateTheme.steel, outline: r * 0.25)
                var cross = Path()
                cross.addLines([point + CGPoint(x: -r * 0.5, y: 0), point + CGPoint(x: r * 0.5, y: 0)])
                cross.move(to: point + CGPoint(x: 0, y: -r * 0.5))
                cross.addLine(to: point + CGPoint(x: 0, y: r * 0.5))
                graphics.stroke(cross, with: .color(SkateTheme.ink), lineWidth: r * 0.22)
            }
        }

        // One sticker per bar slowly lifts off the deck; the rest bounce on beats.
        let bar = audio.beatProgress(at: frame.time) / 4
        let lifted = Int(bar.rounded(.down)) % Self.layout.count
        let lift = sin(.pi * (bar - bar.rounded(.down)))
        for (index, item) in Self.layout.enumerated() {
            let kick = hash01(index, audio.beatCount) > 0.5 ? 1.0 : 0.3
            let bounce = 1 + 0.16 * Double(audio.beatPulse) * kick
            let raise = index == lifted ? lift : 0
            let scale = deckWidth * item.size * CGFloat(bounce + 0.08 * raise) / 2
            let position = center + CGPoint(x: item.u * size.width, y: item.v * deckWidth)

            var g = graphics
            g.translateBy(x: position.x, y: position.y)
            g.rotate(by: .radians(item.rotation + 0.12 * raise * sin(frame.time * 2)))
            g.scaleBy(x: scale, y: scale)

            let shape = path(for: item.sticker)
            let shadowOffset = 0.06 + 0.2 * raise
            var shadow = g
            shadow.translateBy(x: shadowOffset, y: shadowOffset)
            shadow.fill(shape, with: .color(.black.opacity(0.35 + 0.15 * raise)))
            shadow.stroke(shape, with: .color(.black.opacity(0.35 + 0.15 * raise)), style: SkateTheme.outline(0.2))

            g.stroke(shape, with: .color(SkateTheme.ink), style: SkateTheme.outline(0.28))
            g.stroke(shape, with: .color(.white), style: SkateTheme.outline(0.2))
            drawFace(of: item.sticker, shape: shape, in: g, scale: scale, frame: frame)
        }
    }

    /// Sticker outlines in a -1...1 box.
    private func path(for sticker: Sticker) -> Path {
        var path = Path()
        switch sticker {
        case .star:
            path.addLines((0..<10).map { index in
                let angle = Double(index) / 10 * 2 * .pi - .pi / 2
                let r: CGFloat = index % 2 == 0 ? 1 : 0.45
                return CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            })
            path.closeSubpath()
        case .bolt:
            path.addLines([CGPoint(x: 0.15, y: -1), CGPoint(x: -0.55, y: 0.12), CGPoint(x: -0.02, y: 0.12), CGPoint(x: -0.2, y: 1), CGPoint(x: 0.6, y: -0.2), CGPoint(x: 0.06, y: -0.2), CGPoint(x: 0.3, y: -1)])
            path.closeSubpath()
        case .smiley, .eye:
            path.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        case .label:
            path.addRoundedRect(in: CGRect(x: -1.9, y: -0.5, width: 3.8, height: 1.0), cornerSize: CGSize(width: 0.25, height: 0.25))
        case .flame:
            path.move(to: CGPoint(x: 0, y: 1))
            path.addQuadCurve(to: CGPoint(x: -0.75, y: 0.15), control: CGPoint(x: -0.85, y: 0.9))
            path.addQuadCurve(to: CGPoint(x: -0.3, y: -0.6), control: CGPoint(x: -0.65, y: -0.35))
            path.addQuadCurve(to: CGPoint(x: 0.1, y: -1), control: CGPoint(x: -0.05, y: -0.75))
            path.addQuadCurve(to: CGPoint(x: 0.75, y: 0.1), control: CGPoint(x: 0.8, y: -0.5))
            path.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 0.85, y: 0.85))
            path.closeSubpath()
        case .heart:
            path.move(to: CGPoint(x: 0, y: 0.95))
            path.addCurve(to: CGPoint(x: 0, y: -0.45), control1: CGPoint(x: -1.4, y: 0.05), control2: CGPoint(x: -0.6, y: -1.2))
            path.addCurve(to: CGPoint(x: 0, y: 0.95), control1: CGPoint(x: 0.6, y: -1.2), control2: CGPoint(x: 1.4, y: 0.05))
            path.closeSubpath()
        }
        return path
    }

    private func drawFace(of sticker: Sticker, shape: Path, in g: GraphicsContext, scale: CGFloat, frame: AudioFrame) {
        let ink = SkateTheme.ink
        let thin = SkateTheme.outline(0.09)
        switch sticker {
        case .star:
            g.fill(shape, with: .color(SkateTheme.yellow))
        case .bolt:
            g.fill(shape, with: .color(SkateTheme.orange))
        case .smiley:
            g.fill(shape, with: .color(SkateTheme.yellow))
            for x: CGFloat in [-0.35, 0.35] {
                g.fill(Path(ellipseIn: CGRect(x: x - 0.11, y: -0.45, width: 0.22, height: 0.36)), with: .color(ink))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: -0.55, y: 0.2))
            smile.addQuadCurve(to: CGPoint(x: 0.55, y: 0.2), control: CGPoint(x: 0, y: 0.85))
            g.stroke(smile, with: .color(ink), style: SkateTheme.outline(0.12))
        case .label:
            g.fill(shape, with: .color(ink))
            // Text is laid out at real size; laying it out at sticker scale garbles the glyphs.
            var textContext = g
            textContext.scaleBy(x: 1 / scale, y: 1 / scale)
            let text = textContext.resolve(Text("BEATSWALL").font(.system(size: 0.62 * scale, weight: .black, design: .rounded)).foregroundStyle(SkateTheme.yellow))
            textContext.draw(text, at: .zero)
        case .eye:
            g.fill(shape, with: .color(SkateTheme.offWhite))
            // The pupil wanders, darting around with the melody.
            let angle = frame.time * 0.9 + sin(frame.time * 2.3) * 1.5
            let look = CGPoint(x: cos(angle) * 0.3, y: sin(angle) * 0.25) * CGFloat(0.5 + 0.5 * Double(frame.audio.mid))
            g.fill(Path(ellipseIn: CGRect(x: look.x - 0.5, y: look.y - 0.5, width: 1, height: 1)), with: .color(SkateTheme.teal))
            g.fill(Path(ellipseIn: CGRect(x: look.x - 0.22, y: look.y - 0.22, width: 0.44, height: 0.44)), with: .color(ink))
            g.fill(Path(ellipseIn: CGRect(x: look.x - 0.05, y: look.y - 0.32, width: 0.16, height: 0.16)), with: .color(.white))
        case .flame:
            g.fill(shape, with: .color(SkateTheme.orange))
            var inner = Path()
            inner.move(to: CGPoint(x: 0, y: 0.8))
            inner.addQuadCurve(to: CGPoint(x: 0, y: -0.25), control: CGPoint(x: -0.65, y: 0.3))
            inner.addQuadCurve(to: CGPoint(x: 0, y: 0.8), control: CGPoint(x: 0.6, y: 0.35))
            g.fill(inner, with: .color(SkateTheme.yellow))
        case .heart:
            g.fill(shape, with: .color(SkateTheme.pink))
        }
        g.stroke(shape, with: .color(ink), style: thin)
    }
}
