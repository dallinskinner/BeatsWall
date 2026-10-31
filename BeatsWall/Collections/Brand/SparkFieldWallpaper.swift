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

        BrandTheme.backdrop(in: &graphics, size: size)

        let glow = unit * (0.35 + 0.25 * Double(audio.bass))
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(
                Gradient(colors: [BrandTheme.magenta.opacity(0.1 + 0.25 * Double(audio.bass)), .clear]),
                center: center, startRadius: 0, endRadius: glow
            )
        )

        graphics.blendMode = .plusLighter
        for particle in simulation.particles {
            let point = CGPoint(x: (particle.x + particle.burstX) * unit, y: (particle.y + particle.burstY) * unit)
            let heat = min(1, hypot(particle.vx + particle.burstVX, particle.vy + particle.burstVY) / 0.35)
            let twinkle = 0.7 + 0.3 * sin(frame.time * 3 + particle.seed * 40)
            let radius = unit * (0.002 + 0.004 * particle.size) * (1 + 0.7 * pulse)
            // Each spark keeps its own spot on the icon's gradient and burns whiter as it speeds up.
            let color = BrandTheme.gradient(particle.seed).mix(with: BrandTheme.glow, by: heat * 0.7)
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
        /// How far the last kicks threw it from where it's drifting; springs back to zero.
        var burstX: Double = 0
        var burstY: Double = 0
        var burstVX: Double = 0
        var burstVY: Double = 0
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

            // Drift along a slowly evolving flow. It's the curl of a stream function, so it has no
            // sinks: sparks swirl around but never bunch up into lines.
            let diagonal = 0.6 * 1.3 * cos((particle.x + particle.y) * 1.3 + t * 0.11)
            let dPsiDX = 0.8 * 2.1 * cos(particle.x * 2.1 + t * 0.07) + diagonal
            let dPsiDY = -0.7 * 2.7 * sin(particle.y * 2.7 - t * 0.05) + diagonal
            let ease = min(1, dt * 1.5)
            particle.vx += (dPsiDY / 3 * speed - particle.vx) * ease
            particle.vy += (-dPsiDX / 3 * speed - particle.vy) * ease

            // Kicks throw sparks outward from the center, then a spring settles them back to where
            // they're drifting, so the field breathes instead of piling up at the edges.
            if isBeat {
                let dx = particle.x - centerX, dy = particle.y - 0.5
                let distance = max(hypot(dx, dy), 0.05)
                let impulse = 0.6 * burst * (0.5 + particle.seed) / (0.5 + distance * 2)
                particle.burstVX += dx / distance * impulse
                particle.burstVY += dy / distance * impulse
            }
            particle.burstVX += (-18 * particle.burstX - 6 * particle.burstVX) * dt
            particle.burstVY += (-18 * particle.burstY - 6 * particle.burstVY) * dt
            particle.burstX += particle.burstVX * dt
            particle.burstY += particle.burstVY * dt

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
