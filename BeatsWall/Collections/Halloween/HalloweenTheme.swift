//
//  HalloweenTheme.swift
//  BeatsWall
//

import SwiftUI

/// Eerie and atmospheric: silhouettes, fog, moonlight and glowing light sources.
enum HalloweenTheme {
    static let midnight = Color(hex: 0x0A0B14)
    static let silhouette = Color(hex: 0x07080D)
    static let purple = Color(hex: 0x2A1F3D)
    static let haze = Color(hex: 0x3B3552)
    static let fog = Color(hex: 0x8A90A6)
    static let moon = Color(hex: 0xE8E4D0)
    static let pumpkin = Color(hex: 0xFF7518)
    static let candle = Color(hex: 0xFFB347)
    static let ghostGreen = Color(hex: 0x7CFF6B)
    static let bone = Color(hex: 0xE6E1D3)

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.045))
    }

    static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func ellipse(_ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
    }

    static func glow(in graphics: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        graphics.fill(disc(center, radius), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    static func sky(in graphics: inout GraphicsContext, size: CGSize, horizon: CGFloat, low: Color = haze) {
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [midnight, purple, low]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
    }

    static func drawMoon(in graphics: inout GraphicsContext, center: CGPoint, radius: CGFloat, brightness: Double) {
        glow(in: graphics, at: center, radius: radius * 3.2, color: moon, opacity: 0.18 + 0.12 * brightness)
        graphics.fill(disc(center, radius), with: .radialGradient(
            Gradient(colors: [moon, moon.mix(with: Color(hex: 0xBDB6A0), by: 0.6)]),
            center: center + CGPoint(x: -radius * 0.3, y: -radius * 0.3), startRadius: 0, endRadius: radius * 1.4
        ))
        var craters = Path()
        for (dx, dy, r) in [(-0.35, -0.15, 0.2), (0.25, 0.3, 0.14), (0.3, -0.35, 0.1), (-0.1, 0.45, 0.08)] {
            craters.addPath(disc(center + CGPoint(x: dx * radius, y: dy * radius), radius * r))
        }
        graphics.fill(craters, with: .color(Color(hex: 0xA9A28C).opacity(0.45)))
    }

    /// Low drifting fog banks, softened with a blur.
    static func drawFog(in graphics: inout GraphicsContext, size: CGSize, top: CGFloat, drift: Double, density: Double, tint: Color = fog, banks: Int = 14) {
        let unit = min(size.width, size.height)
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.035))
            for index in 0..<banks {
                let span = size.width + unit * 1.2
                let speed = 0.5 + hash01(index, 301)
                let raw = CGFloat(hash01(index, 302)) * span + CGFloat(drift * speed) * unit
                let x = raw - (raw / span).rounded(.down) * span - unit * 0.6
                let y = top + (size.height - top) * CGFloat(hash01(index, 303))
                let rx = unit * CGFloat(0.25 + 0.3 * hash01(index, 304))
                layer.fill(ellipse(CGPoint(x: x, y: y), rx, rx * 0.16), with: .color(tint.opacity(0.035 + 0.075 * density)))
            }
        }
    }

    /// A bat with wings at `flap` (-1 down ... 1 up), spanning `span` from body to wingtip.
    static func batPath(center: CGPoint, span: CGFloat, flap: Double) -> Path {
        var path = Path()
        let tipY = -CGFloat(flap) * span * 0.45
        for side: CGFloat in [-1, 1] {
            path.move(to: center)
            path.addQuadCurve(to: center + CGPoint(x: side * span, y: tipY), control: center + CGPoint(x: side * span * 0.5, y: tipY - span * 0.25))
            path.addQuadCurve(to: center + CGPoint(x: side * span * 0.66, y: tipY * 0.5 + span * 0.12), control: center + CGPoint(x: side * span * 0.86, y: tipY * 0.5 + span * 0.02))
            path.addQuadCurve(to: center + CGPoint(x: side * span * 0.33, y: tipY * 0.25 + span * 0.12), control: center + CGPoint(x: side * span * 0.5, y: tipY * 0.3 + span * 0.02))
            path.addQuadCurve(to: center, control: center + CGPoint(x: side * span * 0.15, y: span * 0.05))
            path.closeSubpath()
        }
        path.addPath(ellipse(center + CGPoint(x: 0, y: span * 0.05), span * 0.12, span * 0.18))
        // Ears.
        path.move(to: center + CGPoint(x: -span * 0.1, y: -span * 0.08))
        path.addLine(to: center + CGPoint(x: -span * 0.07, y: -span * 0.24))
        path.addLine(to: center + CGPoint(x: -span * 0.02, y: -span * 0.1))
        path.move(to: center + CGPoint(x: span * 0.1, y: -span * 0.08))
        path.addLine(to: center + CGPoint(x: span * 0.07, y: -span * 0.24))
        path.addLine(to: center + CGPoint(x: span * 0.02, y: -span * 0.1))
        return path
    }

    /// A gnarled leafless tree, deterministic for a given seed.
    static func drawBarrenTree(in graphics: GraphicsContext, base: CGPoint, height: CGFloat, seed: Int, color: Color = silhouette, depth: Int = 5) {
        func branch(from start: CGPoint, angle: Double, length: CGFloat, width: CGFloat, level: Int, id: Int) {
            let bend = (hash01(seed, id * 3 + 1) - 0.5) * 0.5
            let end = start + CGPoint(x: cos(angle) * length, y: sin(angle) * length)
            let control = start + CGPoint(x: cos(angle + bend) * length * 0.55, y: sin(angle + bend) * length * 0.55)
            var path = Path()
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            graphics.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            guard level > 0 else { return }
            let children = hash01(seed, id * 7 + 2) > 0.8 ? 3 : 2
            for child in 0..<children {
                let spread = 0.35 + 0.35 * hash01(seed, id * 11 + child)
                let side = child == 0 ? -1.0 : (child == 1 ? 1.0 : 0.15)
                branch(
                    from: end,
                    angle: angle + side * spread,
                    length: length * CGFloat(0.62 + 0.18 * hash01(seed, id * 13 + child)),
                    width: width * 0.62,
                    level: level - 1,
                    id: id * 4 + child + 1
                )
            }
        }
        branch(from: base, angle: -.pi / 2 + (hash01(seed, 0) - 0.5) * 0.2, length: height * 0.38, width: height * 0.05, level: depth, id: 1)
    }

    /// A jagged lightning bolt from `start` to `end` with one fork.
    static func lightningPath(from start: CGPoint, to end: CGPoint, seed: Int) -> Path {
        var path = Path()
        let segments = 12
        let delta = end - start
        let normal = CGPoint(x: -delta.y, y: delta.x) * (1 / max(delta.length, 1))
        var points: [CGPoint] = []
        for index in 0...segments {
            let t = CGFloat(index) / CGFloat(segments)
            let jitter = index == 0 || index == segments ? 0 : CGFloat(hash01(seed, index) - 0.5) * delta.length * 0.12
            points.append(start + delta * t + normal * jitter)
        }
        path.addLines(points)
        let forkStart = points[segments / 2]
        path.move(to: forkStart)
        path.addLine(to: forkStart + CGPoint(x: delta.length * 0.12, y: delta.length * 0.1))
        path.addLine(to: forkStart + CGPoint(x: delta.length * 0.18, y: delta.length * 0.25))
        return path
    }
}
