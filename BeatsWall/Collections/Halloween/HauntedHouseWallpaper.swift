//
//  HauntedHouseWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct HauntedHouseWallpaper: View {
    let context: WallpaperContext
    @State private var scene = HauntedScene()

    /// House windows in house-normalized coordinates (0...1 across, 0...1 down).
    private static let windows: [CGRect] = [
        CGRect(x: 0.2, y: 0.55, width: 0.09, height: 0.12), CGRect(x: 0.42, y: 0.55, width: 0.09, height: 0.12),
        CGRect(x: 0.2, y: 0.78, width: 0.09, height: 0.12), CGRect(x: 0.53, y: 0.78, width: 0.09, height: 0.12),
        CGRect(x: 0.73, y: 0.34, width: 0.07, height: 0.1), CGRect(x: 0.73, y: 0.58, width: 0.07, height: 0.1),
        CGRect(x: 0.04, y: 0.75, width: 0.06, height: 0.09),
    ]
    private static let attic = CGPoint(x: 0.39, y: 0.37)

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                let unit = min(size.width, size.height)
                let house = houseRect(size: size, unit: unit)
                let attic = CGPoint(x: house.minX + Self.attic.x * house.width, y: house.minY + Self.attic.y * house.height)
                scene.step(frame: frame, size: size, attic: attic)
                draw(in: &graphics, size: size, unit: unit, house: house, attic: attic, frame: frame)
            }
        }
        .colorEffect(HalloweenTheme.grain())
    }

    private func houseRect(size: CGSize, unit: CGFloat) -> CGRect {
        let width = unit * 0.42
        let height = unit * 0.42
        return CGRect(x: size.width * 0.36 - width / 2, y: size.height * 0.62 - height, width: width, height: height)
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, house: CGRect, attic: CGPoint, frame: AudioFrame) {
        let audio = frame.audio
        let horizon = size.height * 0.7

        HalloweenTheme.sky(in: &graphics, size: size, horizon: horizon)
        // Lightning lights up the whole sky for a moment.
        let flash = scene.flash(at: frame.time)
        if flash > 0 {
            graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xC9C6E8).opacity(0.45 * flash)))
        }
        var stars = Path()
        for index in 0..<50 {
            let r = unit * 0.0014 * CGFloat(0.6 + hash01(index, 2))
            stars.addPath(HalloweenTheme.disc(CGPoint(x: CGFloat(hash01(index, 0)) * size.width, y: CGFloat(hash01(index, 1)) * horizon * 0.6), r))
        }
        graphics.fill(stars, with: .color(.white.opacity(0.45)))

        let moon = CGPoint(x: size.width * 0.62, y: size.height * 0.3)
        HalloweenTheme.drawMoon(in: &graphics, center: moon, radius: unit * 0.15, brightness: Double(audio.level))
        // Thin clouds sliding across the moon.
        for index in 0..<3 {
            let span = size.width + unit
            let raw = CGFloat(hash01(index, 9)) * span + CGFloat(frame.time) * unit * 0.012 * CGFloat(1 + index)
            let x = raw - (raw / span).rounded(.down) * span - unit * 0.5
            let y = moon.y + unit * CGFloat(-0.1 + 0.1 * Double(index))
            graphics.fill(HalloweenTheme.ellipse(CGPoint(x: x, y: y), unit * 0.22, unit * 0.025), with: .color(HalloweenTheme.purple.opacity(0.75)))
        }

        if let bolt = scene.bolt, frame.time - bolt.time < 0.18 {
            let path = HalloweenTheme.lightningPath(
                from: CGPoint(x: size.width * bolt.x, y: 0),
                to: CGPoint(x: size.width * bolt.x + unit * 0.08, y: horizon * 0.85),
                seed: bolt.seed
            )
            graphics.stroke(path, with: .color(Color(hex: 0xC9C6E8).opacity(0.5)), style: StrokeStyle(lineWidth: unit * 0.012, lineCap: .round, lineJoin: .round))
            graphics.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: unit * 0.003, lineCap: .round, lineJoin: .round))
        }

        // Hill.
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 6 {
            let t = Double(x / size.width)
            let rise = exp(-pow((t - 0.36) / 0.28, 2))
            hill.addLine(to: CGPoint(x: x, y: horizon - unit * CGFloat(0.09 * rise) + unit * 0.01 * CGFloat(sin(t * 20))))
            x += 6
        }
        hill.addLine(to: CGPoint(x: size.width + 6, y: size.height))
        hill.closeSubpath()
        graphics.fill(hill, with: .color(HalloweenTheme.silhouette))

        HalloweenTheme.drawBarrenTree(in: graphics, base: CGPoint(x: size.width * 0.1, y: horizon + unit * 0.02), height: unit * 0.55, seed: 3)
        HalloweenTheme.drawBarrenTree(in: graphics, base: CGPoint(x: size.width * 0.86, y: horizon + unit * 0.03), height: unit * 0.45, seed: 8)
        HalloweenTheme.drawBarrenTree(in: graphics, base: CGPoint(x: size.width * 0.6, y: horizon + unit * 0.01), height: unit * 0.22, seed: 11, depth: 4)

        drawHouse(in: &graphics, rect: house, unit: unit, frame: frame)

        for bat in scene.bats {
            let flap = sin(audio.beatProgress(at: frame.time) * 2 * .pi * 2 + bat.seed * 6)
            graphics.fill(HalloweenTheme.batPath(center: bat.position, span: unit * 0.022 * CGFloat(bat.size), flap: flap), with: .color(HalloweenTheme.silhouette))
        }

        HalloweenTheme.drawFog(in: &graphics, size: size, top: horizon - unit * 0.06, drift: frame.time * 0.02, density: 0.5 + 0.5 * Double(audio.mid))
    }

    private func drawHouse(in graphics: inout GraphicsContext, rect: CGRect, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }

        var house = graphics
        // A little crooked, as haunted houses are.
        house.translateBy(x: rect.midX, y: rect.maxY)
        house.rotate(by: .radians(-0.025))
        house.translateBy(x: -rect.midX, y: -rect.maxY)

        var shape = Path()
        shape.addRect(CGRect(origin: p(0.1, 0.45), size: CGSize(width: rect.width * 0.62, height: rect.height * 0.56)))
        shape.addLines([p(0.04, 0.47), p(0.4, 0.2), p(0.76, 0.47)])
        shape.closeSubpath()
        shape.addRect(CGRect(origin: p(0.66, 0.24), size: CGSize(width: rect.width * 0.2, height: rect.height * 0.77)))
        shape.addLines([p(0.63, 0.26), p(0.77, -0.06), p(0.89, 0.26)])
        shape.closeSubpath()
        shape.addRect(CGRect(origin: p(-0.02, 0.68), size: CGSize(width: rect.width * 0.14, height: rect.height * 0.33)))
        shape.addLines([p(-0.05, 0.7), p(0.06, 0.58), p(0.14, 0.7)])
        shape.closeSubpath()
        // Leaning chimney.
        shape.addLines([p(0.18, 0.34), p(0.2, 0.14), p(0.27, 0.15), p(0.26, 0.3)])
        shape.closeSubpath()
        // Porch roof and posts.
        shape.addLines([p(0.3, 0.74), p(0.66, 0.74), p(0.7, 0.8), p(0.26, 0.8)])
        shape.closeSubpath()
        house.fill(shape, with: .color(HalloweenTheme.silhouette))
        var spire = Path()
        spire.addLines([p(0.77, -0.06), p(0.77, -0.13)])
        house.stroke(spire, with: .color(HalloweenTheme.silhouette), lineWidth: unit * 0.004)

        // Windows flicker, each with its own slice of the spectrum.
        var glowContext = house
        glowContext.blendMode = .plusLighter
        for (index, window) in Self.windows.enumerated() {
            let bin = (index * 4 + 3) % AudioFeatures.binCount
            let flicker = 0.85 + 0.15 * sin(frame.time * (11 + Double(index)) + Double(index) * 3)
            let light = min(1, (0.15 + 0.85 * Double(audio.spectrum[bin])) * flicker)
            let color = index == 4 ? HalloweenTheme.ghostGreen : HalloweenTheme.candle
            let frameRect = CGRect(origin: p(window.minX, window.minY), size: CGSize(width: window.width * rect.width, height: window.height * rect.height))
            house.fill(Path(frameRect), with: .color(color.mix(with: .black, by: 0.85 - 0.75 * light)))
            HalloweenTheme.glow(in: glowContext, at: CGPoint(x: frameRect.midX, y: frameRect.midY), radius: frameRect.width * 1.8, color: color, opacity: 0.35 * light)
            var mullions = Path()
            mullions.addLines([CGPoint(x: frameRect.midX, y: frameRect.minY), CGPoint(x: frameRect.midX, y: frameRect.maxY)])
            mullions.move(to: CGPoint(x: frameRect.minX, y: frameRect.midY))
            mullions.addLine(to: CGPoint(x: frameRect.maxX, y: frameRect.midY))
            house.stroke(mullions, with: .color(HalloweenTheme.silhouette), lineWidth: max(1, unit * 0.003))
        }
        // Round attic window, where the bats live.
        let attic = p(Self.attic.x, Self.attic.y)
        let atticLight = 0.2 + 0.8 * Double(audio.beatPulse) * Double(audio.bass)
        house.fill(HalloweenTheme.disc(attic, rect.width * 0.035), with: .color(HalloweenTheme.candle.mix(with: .black, by: 0.85 - 0.7 * atticLight)))
        HalloweenTheme.glow(in: glowContext, at: attic, radius: rect.width * 0.1, color: HalloweenTheme.candle, opacity: 0.3 * atticLight)
    }
}

private final class HauntedScene {
    struct Bat {
        var position: CGPoint
        var velocity: CGPoint
        var born: Double
        var size: Double
        var seed: Double
    }

    struct Bolt {
        var time: Double
        var x: CGFloat
        var seed: Int
    }

    private(set) var bats: [Bat] = []
    private(set) var bolt: Bolt?
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()
    private var lastIdleBat = 0.0

    func flash(at time: Double) -> Double {
        guard let bolt else { return 0 }
        let age = time - bolt.time
        return age >= 0 ? exp(-age * 12) : 0
    }

    func step(frame: AudioFrame, size: CGSize, attic: CGPoint) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        clock.advance(to: frame.time)
        let dt = CGFloat(clock.deltaTime)

        if beatEdge.isNewBeat(audio) {
            if audio.bass > 0.55 {
                spawnBats(count: 3 + Int(4 * Double(audio.level)), from: attic, unit: unit, time: frame.time)
            }
            if audio.bass > 0.8, hash01(audio.beatCount, 13) > 0.7 {
                bolt = Bolt(time: frame.time, x: CGFloat(0.15 + 0.7 * hash01(audio.beatCount, 14)), seed: audio.beatCount)
            }
        }
        // A lone bat now and then, even when it's quiet.
        if frame.time - lastIdleBat > 4 {
            lastIdleBat = frame.time
            spawnBats(count: 1, from: attic, unit: unit, time: frame.time)
        }

        for index in bats.indices {
            let wobble = CGFloat(sin(frame.time * 3 + bats[index].seed * 10)) * unit * 0.06
            bats[index].position = bats[index].position + (bats[index].velocity + CGPoint(x: 0, y: wobble)) * dt
            bats[index].velocity.y -= unit * 0.01 * dt
        }
        bats.removeAll { frame.time - $0.born > 8 || $0.position.x < -unit * 0.1 || $0.position.x > size.width + unit * 0.1 || $0.position.y < -unit * 0.1 }
    }

    private func spawnBats(count: Int, from attic: CGPoint, unit: CGFloat, time: Double) {
        for _ in 0..<count {
            let angle = Double.random(in: (-.pi * 0.95)...(-.pi * 0.05))
            let speed = unit * .random(in: 0.12...0.3)
            bats.append(Bat(
                position: attic,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed * 0.6),
                born: time, size: .random(in: 0.7...1.3), seed: .random(in: 0...1)
            ))
        }
    }
}
