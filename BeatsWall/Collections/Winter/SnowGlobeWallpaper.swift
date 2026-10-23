//
//  SnowGlobeWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct SnowGlobeWallpaper: View {
    let context: WallpaperContext
    @State private var flurry: GlobeSnow

    init(context: WallpaperContext) {
        self.context = context
        _flurry = State(initialValue: GlobeSnow(count: context.isPreview ? 90 : 220))
    }

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                flurry.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(WinterTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let jiggle = CGFloat(sin(frame.time * 45)) * unit * 0.004 * CGFloat(flurry.shake)
        let center = CGPoint(x: size.width / 2 + jiggle, y: size.height * 0.44)
        let radius = unit * 0.33

        // A warm, dark room with out-of-focus lights.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2B1D2E), Color(hex: 0x120C18)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.02))
            layer.blendMode = .plusLighter
            for index in 0..<24 {
                let point = CGPoint(x: CGFloat(hash01(index, 1)) * size.width, y: CGFloat(hash01(index, 2)) * size.height * 0.7)
                let color = WinterTheme.bulbColors[index % WinterTheme.bulbColors.count]
                let brightness = 0.15 + 0.35 * Double(audio.spectrum[(index * 3) % AudioFeatures.binCount])
                layer.fill(WinterTheme.disc(point, unit * CGFloat(0.02 + 0.04 * hash01(index, 3))), with: .color(color.opacity(brightness)))
            }
        }

        // Base.
        var base = Path()
        base.addLines([
            CGPoint(x: center.x - radius * 0.78, y: center.y + radius * 0.82), CGPoint(x: center.x + radius * 0.78, y: center.y + radius * 0.82),
            CGPoint(x: center.x + radius * 0.95, y: center.y + radius * 1.3), CGPoint(x: center.x - radius * 0.95, y: center.y + radius * 1.3),
        ])
        base.closeSubpath()
        graphics.fill(base, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x7A4A2A), Color(hex: 0x3E2414)]),
            startPoint: CGPoint(x: center.x - radius, y: 0), endPoint: CGPoint(x: center.x + radius, y: 0)
        ))
        graphics.fill(Path(CGRect(x: center.x - radius * 0.86, y: center.y + radius * 1.0, width: radius * 1.72, height: radius * 0.07)), with: .color(WinterTheme.gold.opacity(0.85)))

        // Inside the globe.
        let globe = WinterTheme.disc(center, radius)
        var inside = graphics
        inside.clip(to: globe)
        inside.fill(globe, with: .linearGradient(
            Gradient(colors: [WinterTheme.night, WinterTheme.dusk]),
            startPoint: CGPoint(x: 0, y: center.y - radius), endPoint: CGPoint(x: 0, y: center.y + radius)
        ))
        let floor = center.y + radius * 0.45
        var mound = Path()
        mound.move(to: CGPoint(x: center.x - radius, y: center.y + radius))
        mound.addLine(to: CGPoint(x: center.x - radius, y: floor + radius * 0.1))
        mound.addQuadCurve(to: CGPoint(x: center.x + radius, y: floor + radius * 0.1), control: CGPoint(x: center.x, y: floor - radius * 0.2))
        mound.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius))
        mound.closeSubpath()
        inside.fill(mound, with: .color(WinterTheme.snow))

        // A tiny village.
        let houses: [(CGFloat, CGFloat, Color)] = [(-0.45, 0.22, WinterTheme.red), (-0.05, 0.28, Color(hex: 0x4A6FA5)), (0.38, 0.2, WinterTheme.green)]
        for (index, (dx, s, color)) in houses.enumerated() {
            let w = radius * s, h = radius * s * 0.7
            let baseY = floor + radius * 0.02 - radius * 0.06 * (1 - abs(dx) * 1.2)
            let body = CGRect(x: center.x + radius * dx - w / 2, y: baseY - h, width: w, height: h)
            inside.fill(Path(body), with: .color(color))
            var roof = Path()
            roof.addLines([CGPoint(x: body.minX - w * 0.1, y: body.minY), CGPoint(x: body.midX, y: body.minY - h * 0.7), CGPoint(x: body.maxX + w * 0.1, y: body.minY)])
            roof.closeSubpath()
            inside.fill(roof, with: .color(WinterTheme.snow))
            let window = CGRect(x: body.midX - w * 0.12, y: body.minY + h * 0.3, width: w * 0.24, height: h * 0.3)
            let light = 0.5 + 0.5 * Double(audio.spectrum[(index * 7 + 4) % AudioFeatures.binCount])
            inside.fill(Path(window), with: .color(WinterTheme.warm.opacity(0.5 + 0.5 * light)))
        }
        for dx in [-0.75, 0.68, 0.18] as [CGFloat] {
            let (tree, snow) = WinterTheme.pinePath(base: CGPoint(x: center.x + radius * dx, y: floor + radius * 0.06), height: radius * 0.42, tiers: 3)
            inside.fill(tree, with: .color(WinterTheme.pine))
            inside.fill(snow, with: .color(WinterTheme.snow))
        }

        // Snow swirling inside.
        var flakes = Path()
        for flake in flurry.flakes {
            flakes.addPath(WinterTheme.disc(center + CGPoint(x: flake.x * radius, y: flake.y * radius), radius * 0.012 * CGFloat(flake.size)))
        }
        inside.fill(flakes, with: .color(.white.opacity(0.92)))

        // Glass: rim, reflections and a soft highlight.
        graphics.stroke(globe, with: .color(.white.opacity(0.25)), lineWidth: max(1, unit * 0.004))
        var highlight = Path()
        highlight.addArc(center: center, radius: radius * 0.86, startAngle: .degrees(200), endAngle: .degrees(255), clockwise: false)
        graphics.stroke(highlight, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: radius * 0.05, lineCap: .round))
        graphics.fill(WinterTheme.disc(center + CGPoint(x: radius * 0.45, y: -radius * 0.5), radius * 0.05), with: .color(.white.opacity(0.3)))
    }
}

/// Snow inside the globe, in globe-radius units. Bass hits shake it up into a swirl.
private final class GlobeSnow {
    struct Flake {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat = 0
        var vy: CGFloat = 0
        var size: Double
    }

    private(set) var flakes: [Flake]
    private(set) var shake: Double = 0
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()

    init(count: Int) {
        flakes = (0..<count).map { _ in
            let angle = Double.random(in: 0..<(2 * .pi))
            let r = sqrt(Double.random(in: 0...1)) * 0.85
            return Flake(x: CGFloat(cos(angle) * r), y: CGFloat(sin(angle) * r), size: .random(in: 0.5...1.4))
        }
    }

    func step(frame: AudioFrame) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        let dt = CGFloat(clock.deltaTime)
        if beatEdge.isNewBeat(audio), audio.bass > 0.5 {
            shake = min(1.5, shake + Double(audio.bass))
            for index in flakes.indices {
                flakes[index].vx += .random(in: -0.6...0.6) * CGFloat(audio.bass)
                flakes[index].vy -= .random(in: 0.2...1.0) * CGFloat(audio.bass)
            }
        }
        shake *= exp(-Double(dt) * 2.5)

        for index in flakes.indices {
            var flake = flakes[index]
            // Swirl around the center while shaken, then drift gently down.
            let swirl = CGFloat(shake) * 0.8
            flake.vx += (-flake.y * swirl - flake.vx * 1.5) * dt
            flake.vy += (flake.x * swirl + 0.06 - flake.vy * 1.5) * dt
            flake.x += flake.vx * dt + CGFloat(sin(frame.time + flake.size * 10)) * 0.01 * dt
            flake.y += flake.vy * dt
            // Stay inside the glass and settle on the snow.
            let distance = hypot(flake.x, flake.y)
            if distance > 0.95 {
                flake.x *= 0.95 / distance
                flake.y *= 0.95 / distance
                flake.vx *= -0.3
                flake.vy *= -0.3
            }
            if flake.y > 0.42 {
                flake.y = 0.42
                flake.vy = 0
                flake.vx *= 0.5
            }
            flakes[index] = flake
        }
    }
}
