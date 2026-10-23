//
//  RainyWindowWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct RainyWindowWallpaper: View {
    let context: WallpaperContext
    @State private var rain = WindowRain()

    private static let bokehColors = [Color(hex: 0xFFB86B), Color(hex: 0xFF5A5F), Color(hex: 0x2EC4B6), Color(hex: 0xFFE8C2), Color(hex: 0x8E7CFF)]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                rain.step(frame: frame, size: size)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.02)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)

        // Blurred city lights beyond the glass, each pulsing with its own spectrum bin.
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.018))
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x0A1222), Color(hex: 0x1B2438)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
            layer.blendMode = .plusLighter
            for index in 0..<46 {
                let bin = index % AudioFeatures.binCount
                let center = CGPoint(x: CGFloat(hash01(index, 61)) * size.width, y: size.height * CGFloat(0.3 + 0.65 * hash01(index, 62)))
                let radius = unit * CGFloat(0.025 + 0.055 * hash01(index, 63))
                let color = Self.bokehColors[Int(hash01(index, 64) * Double(Self.bokehColors.count)) % Self.bokehColors.count]
                let brightness = 0.28 + 0.7 * Double(audio.spectrum[bin])
                layer.fill(NatureTheme.disc(center, radius), with: .radialGradient(
                    Gradient(colors: [color.opacity(brightness), color.opacity(brightness * 0.6), color.opacity(0)]),
                    center: center, startRadius: 0, endRadius: radius
                ))
            }
        }

        // Rain falling outside, heavier when the music is louder.
        var streaks = Path()
        let streakCount = 40 + Int(140 * Double(audio.level))
        for index in 0..<streakCount {
            let speed = 1.2 + hash01(index, 71)
            let fall = (hash01(index, 72) + frame.time * speed * 0.6).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(hash01(index, 73)) * size.width + CGFloat(fall) * unit * 0.05
            let y = CGFloat(fall) * (size.height + unit * 0.1) - unit * 0.05
            streaks.move(to: CGPoint(x: x, y: y))
            streaks.addLine(to: CGPoint(x: x - unit * 0.006, y: y - unit * 0.04))
        }
        graphics.stroke(streaks, with: .color(.white.opacity(0.12)), lineWidth: max(1, unit * 0.0012))

        // Beads of water stuck to the glass.
        let beads = 90 + Int(90 * Double(audio.level))
        for index in 0..<beads {
            let center = CGPoint(x: CGFloat(hash01(index, 81)) * size.width, y: CGFloat(hash01(index, 82)) * size.height)
            drawDrop(in: &graphics, center: center, radius: unit * CGFloat(0.002 + 0.005 * pow(hash01(index, 83), 2)))
        }

        // Drops that start running on the beat, leaving a wet trail.
        for drop in rain.drops {
            if drop.trail.count > 1 {
                var trail = Path()
                trail.addLines(drop.trail)
                graphics.stroke(trail, with: .color(Color(hex: 0x9FB4C8).opacity(0.18)), style: StrokeStyle(lineWidth: drop.radius * 1.1, lineCap: .round, lineJoin: .round))
            }
            drawDrop(in: &graphics, center: drop.position, radius: drop.radius)
        }

        // Window frame.
        let bar = unit * 0.03
        var frame = Path(CGRect(x: 0, y: 0, width: size.width, height: bar))
        frame.addRect(CGRect(x: 0, y: size.height - bar, width: size.width, height: bar))
        frame.addRect(CGRect(x: 0, y: 0, width: bar, height: size.height))
        frame.addRect(CGRect(x: size.width - bar, y: 0, width: bar, height: size.height))
        frame.addRect(CGRect(x: size.width / 2 - bar * 0.4, y: 0, width: bar * 0.8, height: size.height))
        graphics.fill(frame, with: .color(Color(hex: 0x070B12)))
    }

    private func drawDrop(in graphics: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        graphics.fill(NatureTheme.disc(center + CGPoint(x: 0, y: radius * 0.25), radius), with: .color(.black.opacity(0.25)))
        graphics.fill(NatureTheme.disc(center, radius), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xC8D8E8).opacity(0.15), Color(hex: 0xC8D8E8).opacity(0.45)]),
            center: center, startRadius: 0, endRadius: radius
        ))
        graphics.fill(NatureTheme.disc(center + CGPoint(x: -radius * 0.35, y: -radius * 0.35), radius * 0.28), with: .color(.white.opacity(0.7)))
    }
}

private final class WindowRain {
    struct Drop {
        var position: CGPoint
        var velocity: CGFloat
        var radius: CGFloat
        var trail: [CGPoint]
        var seed: Double
    }

    private(set) var drops: [Drop] = []
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()

    func step(frame: AudioFrame, size: CGSize) {
        let unit = min(size.width, size.height)
        clock.advance(to: frame.time)
        let dt = CGFloat(clock.deltaTime)

        if beatEdge.isNewBeat(frame.audio) {
            let count = 1 + Int(2 * Double(frame.audio.bass))
            for _ in 0..<count {
                let start = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...(size.height * 0.45)))
                drops.append(Drop(position: start, velocity: unit * 0.05, radius: unit * .random(in: 0.006...0.011), trail: [start], seed: .random(in: 0...10)))
            }
        }
        for index in drops.indices {
            drops[index].velocity += unit * 0.5 * dt
            drops[index].position.y += drops[index].velocity * dt
            drops[index].position.x += CGFloat(sin(frame.time * 3 + drops[index].seed)) * unit * 0.01 * dt
            drops[index].trail.append(drops[index].position)
            if drops[index].trail.count > 60 { drops[index].trail.removeFirst() }
        }
        drops.removeAll { $0.position.y > size.height + unit * 0.1 }
    }
}
