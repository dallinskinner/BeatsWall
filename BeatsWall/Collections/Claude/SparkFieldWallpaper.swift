//
//  SparkFieldWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct SparkFieldWallpaper: View {
    let context: WallpaperContext
    @State private var simulation: SparkFieldSimulation

    init(context: WallpaperContext) {
        self.context = context
        _simulation = State(initialValue: SparkFieldSimulation(count: context.isPreview ? 180 : 700))
    }

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                simulation.step(frame: frame, aspect: size.width / max(size.height, 1))
                draw(in: &graphics, size: size, frame: frame)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = size.height
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let pulse = Double(audio.beatPulse)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [ClaudeTheme.warmDark, ClaudeTheme.ink]),
            center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
        ))

        let glow = unit * (0.35 + 0.25 * Double(audio.bass))
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(
                Gradient(colors: [ClaudeTheme.clay.opacity(0.08 + 0.2 * Double(audio.bass)), .clear]),
                center: center, startRadius: 0, endRadius: glow
            )
        )

        graphics.blendMode = .plusLighter
        for particle in simulation.particles {
            let point = CGPoint(x: particle.x * unit, y: particle.y * unit)
            let heat = min(1, hypot(particle.vx, particle.vy) / 0.35)
            let twinkle = 0.7 + 0.3 * sin(frame.time * 3 + particle.seed * 40)
            let radius = unit * (0.002 + 0.004 * particle.size) * (1 + 0.7 * pulse)
            let color = ClaudeTheme.terracotta.mix(with: ClaudeTheme.cream, by: heat * 0.8)
                .opacity((0.6 + 0.4 * heat) * twinkle)

            if particle.size > 0.65 {
                graphics.fill(sparkle(at: point, radius: radius * 2.6), with: .color(color))
            } else {
                graphics.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
            }
        }
    }

    /// A small four-pointed star.
    private func sparkle(at point: CGPoint, radius: CGFloat) -> Path {
        let waist = radius * 0.22
        var path = Path()
        path.move(to: CGPoint(x: point.x, y: point.y - radius))
        path.addQuadCurve(to: CGPoint(x: point.x + radius, y: point.y), control: CGPoint(x: point.x + waist, y: point.y - waist))
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y + radius), control: CGPoint(x: point.x + waist, y: point.y + waist))
        path.addQuadCurve(to: CGPoint(x: point.x - radius, y: point.y), control: CGPoint(x: point.x - waist, y: point.y + waist))
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - radius), control: CGPoint(x: point.x - waist, y: point.y - waist))
        return path
    }
}

/// Particles live in height-normalized space: y in 0...1, x in 0...aspect.
private final class SparkFieldSimulation {
    struct Particle {
        var x: Double
        var y: Double
        var vx: Double = 0
        var vy: Double = 0
        var size: Double
        var seed: Double
    }

    private(set) var particles: [Particle]
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()

    init(count: Int) {
        particles = (0..<count).map { _ in
            Particle(x: .random(in: 0...1.8), y: .random(in: 0...1), size: pow(.random(in: 0...1), 2), seed: .random(in: 0...1))
        }
    }

    func step(frame: AudioFrame, aspect: Double) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        let dt = min(clock.deltaTime, 1 / 20)
        let isBeat = beatEdge.isNewBeat(audio)

        let speed = 0.015 + 0.12 * Double(audio.treble) + 0.05 * Double(audio.mid)
        let burst = 0.25 + 0.6 * Double(audio.bass)
        let centerX = aspect / 2
        let t = frame.time

        for index in particles.indices {
            var particle = particles[index]

            // Drift along a slowly evolving flow field.
            let angle = sin(particle.x * 2.1 + t * 0.07) * 1.7
                + cos(particle.y * 2.7 - t * 0.05) * 1.9
                + sin((particle.x + particle.y) * 1.3 + t * 0.11)
            let ease = min(1, dt * 1.5)
            particle.vx += (cos(angle) * speed - particle.vx) * ease
            particle.vy += (sin(angle) * speed - particle.vy) * ease

            if isBeat {
                let dx = particle.x - centerX, dy = particle.y - 0.5
                let distance = max(hypot(dx, dy), 0.05)
                let impulse = burst * (0.5 + particle.seed) / (0.5 + distance * 2)
                particle.vx += dx / distance * impulse
                particle.vy += dy / distance * impulse
            }

            particle.x += particle.vx * dt
            particle.y += particle.vy * dt

            if particle.x < -0.05 { particle.x += aspect + 0.1 }
            if particle.x > aspect + 0.05 { particle.x -= aspect + 0.1 }
            if particle.y < -0.05 { particle.y += 1.1 }
            if particle.y > 1.05 { particle.y -= 1.1 }

            particles[index] = particle
        }
    }
}
