//
//  HalfpipeSessionWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct HalfpipeSessionWallpaper: View {
    let context: WallpaperContext
    @State private var clouds = PhaseClock()

    /// How far past the coping the pendulum swings; the excess becomes air time.
    private static let swing = 1.25
    /// Angle of the transition at the coping (90° would be full vert).
    private static let lipAngle = 72 * Double.pi / 180

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.03)))
    }

    private struct Ramp {
        var leftCenter: CGPoint
        var rightCenter: CGPoint
        var radius: CGFloat
        var flat: CGFloat
        var bottom: CGFloat
        var lip: Double

        var arcLength: CGFloat { radius * lip }
        var totalLength: CGFloat { arcLength * 2 + flat }
        var leftCoping: CGPoint { leftCenter + CGPoint(x: -sin(lip) * radius, y: cos(lip) * radius) }
        var rightCoping: CGPoint { rightCenter + CGPoint(x: sin(lip) * radius, y: cos(lip) * radius) }

        /// Point and surface angle (of the rightward tangent) for s in -1...1 across the ramp.
        func surface(at s: Double) -> (point: CGPoint, angle: Double) {
            let distance = CGFloat((s + 1) / 2) * totalLength
            if distance < arcLength {
                let phi = lip - Double(distance / radius)
                return (leftCenter + CGPoint(x: -sin(phi) * radius, y: cos(phi) * radius), phi)
            } else if distance < arcLength + flat {
                return (CGPoint(x: leftCenter.x + distance - arcLength, y: bottom), 0)
            } else {
                let phi = Double((distance - arcLength - flat) / radius)
                return (rightCenter + CGPoint(x: sin(phi) * radius, y: cos(phi) * radius), -phi)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let unit = min(size.width, size.height)
        let outline = unit * 0.006
        let center = size.width / 2
        let bottom = size.height * 0.84
        let radius = unit * 0.3
        let flat = unit * 0.32
        let ramp = Ramp(
            leftCenter: CGPoint(x: center - flat / 2, y: bottom - radius),
            rightCenter: CGPoint(x: center + flat / 2, y: bottom - radius),
            radius: radius, flat: flat, bottom: bottom, lip: Self.lipAngle
        )
        let groundY = bottom + unit * 0.05

        drawSky(in: &graphics, size: size, unit: unit, outline: outline, frame: frame)

        // Ground.
        graphics.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)), with: .color(SkateTheme.concrete))
        var groundLine = Path()
        groundLine.addLines([CGPoint(x: 0, y: groundY), CGPoint(x: size.width, y: groundY)])
        graphics.stroke(groundLine, with: .color(SkateTheme.ink), lineWidth: outline)

        drawRamp(in: &graphics, ramp: ramp, groundY: groundY, unit: unit, outline: outline)
        drawSkater(in: &graphics, ramp: ramp, unit: unit, frame: frame)
    }

    private func drawSky(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, outline: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [SkateTheme.teal, Color(hex: 0xBDEFE9)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.85)
        ))

        // Sun with rays that kick out on the beat.
        let sunCenter = CGPoint(x: size.width * 0.8, y: size.height * 0.2)
        let sunRadius = unit * 0.08
        let pulse = CGFloat(audio.beatPulse)
        var rays = Path()
        for index in 0..<12 {
            let angle = Double(index) / 12 * 2 * .pi + frame.time * 0.15
            let inner = sunRadius * 1.3
            let outer = sunRadius * (1.75 + 0.35 * pulse + 0.25 * CGFloat(audio.bass))
            rays.move(to: sunCenter + CGPoint(x: cos(angle) * inner, y: sin(angle) * inner))
            rays.addLine(to: sunCenter + CGPoint(x: cos(angle) * outer, y: sin(angle) * outer))
        }
        graphics.stroke(rays, with: .color(SkateTheme.ink), style: SkateTheme.outline(unit * 0.014 + outline * 2))
        graphics.stroke(rays, with: .color(SkateTheme.yellow), style: SkateTheme.outline(unit * 0.014))
        graphics.fillOutlined(
            Path(ellipseIn: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)),
            SkateTheme.yellow, outline: outline
        )

        // Rolling hills behind the ramp.
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: size.height))
        for step in 0...40 {
            let x = size.width * CGFloat(step) / 40
            let y = size.height * 0.62 - unit * 0.06 * CGFloat(sin(Double(step) * 0.45) + 0.5 * sin(Double(step) * 1.1 + 1))
            hills.addLine(to: CGPoint(x: x, y: y))
        }
        hills.addLine(to: CGPoint(x: size.width, y: size.height))
        hills.closeSubpath()
        graphics.fill(hills, with: .color(Color(hex: 0x6FD3C7)))

        // Clouds drifting with the overall energy.
        let drift = clouds.advance(to: frame.time, speed: 0.012 + 0.03 * Double(audio.level))
        for index in 0..<4 {
            let span = size.width + unit * 0.6
            let x = (CGFloat(hash01(index, 3)) * span + CGFloat(drift) * unit).truncatingRemainder(dividingBy: span) - unit * 0.3
            let y = size.height * (0.1 + 0.25 * CGFloat(hash01(index, 5)))
            let scale = unit * (0.05 + 0.04 * CGFloat(hash01(index, 9)))
            var cloud = Path()
            for (dx, dy, r) in [(-1.2, 0.2, 0.8), (0.0, -0.3, 1.1), (1.2, 0.15, 0.85), (0.4, 0.4, 0.8), (-0.5, 0.45, 0.75)] {
                cloud.addEllipse(in: CGRect(x: x + (dx - r) * scale, y: y + (dy - r) * scale, width: 2 * r * scale, height: 2 * r * scale))
            }
            graphics.stroke(cloud, with: .color(SkateTheme.ink), lineWidth: outline * 2)
            graphics.fill(cloud, with: .color(SkateTheme.offWhite))
        }
    }

    private func drawRamp(in graphics: inout GraphicsContext, ramp: Ramp, groundY: CGFloat, unit: CGFloat, outline: CGFloat) {
        let deckWidth = unit * 0.22
        let left = ramp.leftCoping
        let right = ramp.rightCoping

        var surface = Path()
        surface.move(to: CGPoint(x: left.x - deckWidth, y: left.y))
        for step in 0...60 {
            surface.addLine(to: ramp.surface(at: -1 + 2 * Double(step) / 60).point)
        }
        surface.addLine(to: CGPoint(x: right.x + deckWidth, y: right.y))

        var body = surface
        body.addLine(to: CGPoint(x: right.x + deckWidth, y: groundY))
        body.addLine(to: CGPoint(x: left.x - deckWidth, y: groundY))
        body.closeSubpath()
        graphics.fill(body, with: .color(SkateTheme.wood))

        // Framing visible through the side panel.
        var framing = Path()
        var x = left.x - deckWidth + unit * 0.06
        while x < right.x + deckWidth {
            framing.move(to: CGPoint(x: x, y: groundY))
            framing.addLine(to: CGPoint(x: x, y: left.y))
            x += unit * 0.075
        }
        for side: CGFloat in [-1, 1] {
            let edge = side < 0 ? left.x - deckWidth : right.x + deckWidth
            let inner = side < 0 ? left.x : right.x
            framing.move(to: CGPoint(x: edge, y: groundY))
            framing.addLine(to: CGPoint(x: inner, y: left.y + unit * 0.02))
        }
        var clipped = graphics
        clipped.clip(to: body)
        clipped.stroke(framing, with: .color(SkateTheme.woodShade), lineWidth: outline * 1.4)

        graphics.stroke(body, with: .color(SkateTheme.ink), style: SkateTheme.outline(outline))
        // Riding surface and coping.
        graphics.stroke(surface, with: .color(SkateTheme.ink), style: SkateTheme.outline(unit * 0.014 + outline * 2))
        graphics.stroke(surface, with: .color(Color(hex: 0x8A93A0)), style: SkateTheme.outline(unit * 0.014))
        for coping in [left, right] {
            let r = unit * 0.011
            graphics.fillOutlined(Path(ellipseIn: CGRect(x: coping.x - r, y: coping.y - r, width: r * 2, height: r * 2)), SkateTheme.steel, outline: outline)
        }
    }

    private func drawSkater(in graphics: inout GraphicsContext, ramp: Ramp, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let figureUnit = unit * 0.024
        let beat = audio.beatProgress(at: frame.time)
        // Pendulum locked to the beat: whole beats land at the coping, alternating sides.
        let s = -Self.swing * cos(.pi * beat)
        let movingRight = sin(.pi * beat) >= 0

        if abs(s) <= 1 {
            let (point, angle) = ramp.surface(at: s)
            let normal = CGPoint(x: sin(angle), y: -cos(angle))
            var pose = SkaterPose()
            pose.crouch = 0.15 + 0.55 * (1 - abs(s))
            pose.armsOut = 0.35 + 0.25 * Double(audio.mid)
            pose.lean = 0.1
            SkaterFigure.draw(
                in: graphics, at: point + normal * (SkaterFigure.wheelBase * figureUnit),
                unit: figureUnit, rotation: angle, facing: movingRight ? 1 : -1, pose: pose
            )
            return
        }

        // Airborne above the coping: rise, turn around at the apex, and drop back in.
        let nearestBeat = beat.rounded()
        let edge = acos(1 / Self.swing)
        let progress = min(max((Double.pi * (beat - nearestBeat) + edge) / (2 * edge), 0), 1)
        let isRight = s > 0
        let lip = isRight ? ramp.rightCoping : ramp.leftCoping
        let angle = isRight ? -Self.lipAngle : Self.lipAngle
        let upWall = isRight ? CGPoint(x: cos(Self.lipAngle), y: -sin(Self.lipAngle)) : CGPoint(x: -cos(Self.lipAngle), y: -sin(Self.lipAngle))
        let normal = CGPoint(x: sin(angle), y: -cos(angle))
        let height = unit * (0.05 + 0.16 * CGFloat(audio.bass)) * CGFloat(sin(.pi * progress))

        let beatNumber = Int(nearestBeat)
        let strong = audio.level > 0.3 && hash01(beatNumber, 7) > 0.3
        let pose = SkateTrick.forBeat(beatNumber, strong: strong).pose(progress: progress)
        // Turn around at the apex: narrow a little, then snap to the new direction.
        let turn = cos(.pi * progress)
        let facing = (isRight ? 1 : -1) * (turn < 0 ? -1 : 1) * max(abs(turn), 0.6)

        SkaterFigure.draw(
            in: graphics, at: lip + upWall * height + normal * (SkaterFigure.wheelBase * figureUnit),
            unit: figureUnit, rotation: angle, facing: facing, pose: pose
        )
    }
}
