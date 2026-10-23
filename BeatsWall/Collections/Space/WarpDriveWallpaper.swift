//
//  WarpDriveWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct WarpDriveWallpaper: View {
    let context: WallpaperContext
    @State private var field: WarpField

    init(context: WallpaperContext) {
        self.context = context
        _field = State(initialValue: WarpField(count: context.isPreview ? 200 : 650))
    }

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                field.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let pulse = Double(audio.beatPulse)

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [SpaceTheme.deep, SpaceTheme.void]),
            center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.6
        ))
        let core = unit * (0.12 + 0.12 * CGFloat(audio.bass))
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)),
            with: .radialGradient(Gradient(colors: [SpaceTheme.violet.opacity(0.5), .clear]), center: center, startRadius: 0, endRadius: core)
        )

        // Each star streaks from where it was a moment ago to where it is now.
        let projection = unit * 0.5
        let streak = 0.02 + field.speed * 0.05
        graphics.blendMode = .plusLighter
        for star in field.stars {
            let tail = min(star.z + streak, 1)
            let head = center + CGPoint(x: star.x / star.z, y: star.y / star.z) * projection
            let back = center + CGPoint(x: star.x / tail, y: star.y / tail) * projection
            guard head.x > -50, head.x < size.width + 50, head.y > -50, head.y < size.height + 50 else { continue }
            var line = Path()
            line.move(to: back)
            line.addLine(to: head)
            let nearness = 1 - star.z
            let color = Color.white.mix(with: star.tint > 0.5 ? SpaceTheme.ice : SpaceTheme.pink, by: 0.25 + 0.3 * star.tint)
            graphics.stroke(
                line,
                with: .color(color.opacity(min(1, nearness * 1.6))),
                style: StrokeStyle(lineWidth: max(0.7, unit * 0.004 * nearness), lineCap: .round)
            )
        }
        graphics.blendMode = .normal

        // A white flash on big beats, as if jumping to warp.
        if pulse > 0.05 {
            graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.14 * pow(pulse, 3) * Double(audio.bass))))
        }
    }
}

private final class WarpField {
    struct Star {
        var x: Double
        var y: Double
        var z: Double
        var tint: Double
    }

    private(set) var stars: [Star]
    private(set) var speed: Double = 0.2
    private let clock = PhaseClock()

    init(count: Int) {
        stars = (0..<count).map { _ in WarpField.spawn(z: .random(in: 0.05...1)) }
    }

    private static func spawn(z: Double) -> Star {
        let angle = Double.random(in: 0..<(2 * .pi))
        let radius = Double.random(in: 0.06...1.4)
        return Star(x: cos(angle) * radius, y: sin(angle) * radius, z: z, tint: .random(in: 0...1))
    }

    func step(frame: AudioFrame) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        let target = 0.12 + 0.55 * Double(audio.level) + 1.3 * pow(Double(audio.beatPulse), 2)
        speed += (target - speed) * min(1, clock.deltaTime * 6)
        for index in stars.indices {
            stars[index].z -= speed * clock.deltaTime
            if stars[index].z < 0.03 {
                stars[index] = WarpField.spawn(z: 1)
            }
        }
    }
}
