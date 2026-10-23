//
//  GraveyardRaveWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct GraveyardRaveWallpaper: View {
    let context: WallpaperContext
    @State private var fog = PhaseClock()

    private static let skeletons: [CGFloat] = [0.2, 0.41, 0.6, 0.8]
    private static let beamColors = [HalloweenTheme.ghostGreen, Color(hex: 0x9B6BFF), HalloweenTheme.ghostGreen, Color(hex: 0x9B6BFF)]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(HalloweenTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.68
        let beat = audio.beatProgress(at: frame.time)
        let pulse = Double(audio.beatPulse)
        let drift = fog.advance(to: frame.time, speed: 0.03 + 0.04 * Double(audio.level))

        HalloweenTheme.sky(in: &graphics, size: size, horizon: horizon, low: Color(hex: 0x1E2E2A))
        HalloweenTheme.drawMoon(in: &graphics, center: CGPoint(x: size.width * 0.16, y: size.height * 0.17), radius: unit * 0.05, brightness: 0.3)

        // Ghost-light beams sweeping in tempo.
        var beams = graphics
        beams.blendMode = .plusLighter
        for index in 0..<4 {
            let origin = CGPoint(x: size.width * CGFloat(0.12 + 0.25 * Double(index)), y: horizon + unit * 0.02)
            let angle = -Double.pi / 2 + sin(beat * .pi / 4 + Double(index) * 1.3) * 0.55
            let length = size.height * 1.3
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let normal = CGPoint(x: -direction.y, y: direction.x) * (unit * 0.11)
            var beam = Path()
            beam.addLines([origin, origin + direction * length + normal, origin + direction * length - normal])
            beam.closeSubpath()
            let color = Self.beamColors[index]
            beams.fill(beam, with: .linearGradient(
                Gradient(colors: [color.opacity(0.16 + 0.3 * pulse), color.opacity(0)]),
                startPoint: origin, endPoint: origin + direction * length
            ))
        }

        // Chapel on the far hill.
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: size.height))
        var x: CGFloat = 0
        while x <= size.width + 6 {
            hill.addLine(to: CGPoint(x: x, y: horizon - unit * CGFloat(0.05 * exp(-pow(Double(x / size.width) - 0.74, 2) / 0.03))))
            x += 6
        }
        hill.addLine(to: CGPoint(x: size.width + 6, y: size.height))
        hill.closeSubpath()
        graphics.fill(hill, with: .color(Color(hex: 0x0E0F18)))
        let chapel = CGPoint(x: size.width * 0.74, y: horizon - unit * 0.045)
        var church = Path(CGRect(x: chapel.x - unit * 0.06, y: chapel.y - unit * 0.07, width: unit * 0.12, height: unit * 0.07))
        church.addLines([chapel + CGPoint(x: -unit * 0.07, y: -unit * 0.07), chapel + CGPoint(x: 0, y: -unit * 0.12), chapel + CGPoint(x: unit * 0.07, y: -unit * 0.07)])
        church.closeSubpath()
        church.addRect(CGRect(x: chapel.x + unit * 0.035, y: chapel.y - unit * 0.17, width: unit * 0.03, height: unit * 0.12))
        church.addLines([chapel + CGPoint(x: unit * 0.03, y: -unit * 0.17), chapel + CGPoint(x: unit * 0.05, y: -unit * 0.23), chapel + CGPoint(x: unit * 0.07, y: -unit * 0.17)])
        church.closeSubpath()
        graphics.fill(church, with: .color(Color(hex: 0x0E0F18)))
        graphics.fill(Path(roundedRect: CGRect(x: chapel.x - unit * 0.012, y: chapel.y - unit * 0.06, width: unit * 0.024, height: unit * 0.03), cornerRadius: unit * 0.012), with: .color(Color(hex: 0x9B6BFF).opacity(0.3 + 0.5 * pulse)))

        // Ground, fence and the back row of graves.
        graphics.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height)), with: .color(HalloweenTheme.silhouette))
        drawFence(in: &graphics, size: size, unit: unit, y: horizon + unit * 0.01)
        for index in 0..<9 {
            drawTombstone(in: &graphics, base: CGPoint(x: size.width * CGFloat(0.05 + 0.11 * Double(index)), y: horizon + unit * 0.06), scale: unit * 0.045, kind: index % 3, tilt: (hash01(index, 3) - 0.5) * 0.2, color: Color(hex: 0x16151F))
        }

        for (index, position) in Self.skeletons.enumerated() {
            drawSkeleton(in: graphics, feet: CGPoint(x: size.width * position, y: size.height * 0.86), unit: unit * 0.017, beat: beat + Double(index % 2) * 0.0, index: index, audio: audio)
        }

        // Front row of graves.
        for index in 0..<5 {
            drawTombstone(in: &graphics, base: CGPoint(x: size.width * CGFloat(0.1 + 0.22 * Double(index) + 0.04 * hash01(index, 8)), y: size.height * 0.98), scale: unit * 0.07, kind: (index + 1) % 3, tilt: (hash01(index, 9) - 0.5) * 0.25, color: HalloweenTheme.silhouette)
        }

        HalloweenTheme.drawFog(
            in: &graphics, size: size, top: horizon, drift: drift, density: 0.35 + 0.4 * pulse,
            tint: HalloweenTheme.fog.mix(with: HalloweenTheme.ghostGreen, by: 0.1 + 0.3 * pulse)
        )
    }

    private func drawFence(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, y: CGFloat) {
        var fence = Path()
        var x = unit * 0.01
        while x < size.width {
            fence.move(to: CGPoint(x: x, y: y))
            fence.addLine(to: CGPoint(x: x, y: y - unit * 0.07))
            fence.move(to: CGPoint(x: x - unit * 0.006, y: y - unit * 0.066))
            fence.addLine(to: CGPoint(x: x, y: y - unit * 0.08))
            fence.addLine(to: CGPoint(x: x + unit * 0.006, y: y - unit * 0.066))
            x += unit * 0.025
        }
        fence.move(to: CGPoint(x: 0, y: y - unit * 0.055))
        fence.addLine(to: CGPoint(x: size.width, y: y - unit * 0.055))
        fence.move(to: CGPoint(x: 0, y: y - unit * 0.015))
        fence.addLine(to: CGPoint(x: size.width, y: y - unit * 0.015))
        graphics.stroke(fence, with: .color(Color(hex: 0x111019)), lineWidth: max(1, unit * 0.003))
    }

    private func drawTombstone(in graphics: inout GraphicsContext, base: CGPoint, scale: CGFloat, kind: Int, tilt: Double, color: Color) {
        var g = graphics
        g.translateBy(x: base.x, y: base.y)
        g.rotate(by: .radians(tilt))
        g.scaleBy(x: scale, y: scale)
        var path = Path()
        switch kind {
        case 0:
            path.move(to: CGPoint(x: -0.6, y: 0))
            path.addLine(to: CGPoint(x: -0.6, y: -1.2))
            path.addQuadCurve(to: CGPoint(x: 0.6, y: -1.2), control: CGPoint(x: 0, y: -2.0))
            path.addLine(to: CGPoint(x: 0.6, y: 0))
            path.closeSubpath()
        case 1:
            path.addRect(CGRect(x: -0.15, y: -2.0, width: 0.3, height: 2.0))
            path.addRect(CGRect(x: -0.6, y: -1.55, width: 1.2, height: 0.28))
        default:
            path.addLines([CGPoint(x: -0.35, y: 0), CGPoint(x: -0.25, y: -2.1), CGPoint(x: 0, y: -2.45), CGPoint(x: 0.25, y: -2.1), CGPoint(x: 0.35, y: 0)])
            path.closeSubpath()
        }
        g.fill(path, with: .color(color))
    }

    /// A dancing skeleton. Units: ~10 tall, origin between the feet.
    private func drawSkeleton(in graphics: GraphicsContext, feet: CGPoint, unit: CGFloat, beat: Double, index: Int, audio: AudioFeatures) {
        var g = graphics
        g.translateBy(x: feet.x, y: feet.y)
        g.scaleBy(x: unit, y: unit)
        let bone = HalloweenTheme.bone
        let boneStyle = StrokeStyle(lineWidth: 0.32, lineCap: .round, lineJoin: .round)

        // Drop on the beat, sway side to side, kick alternate feet.
        let swing = sin(.pi * beat)
        let drop = 0.9 * (1 - abs(swing)) * (0.5 + Double(audio.bass))
        let sway = CGFloat(swing) * 0.7
        let kick = max(0, swing) * (Int(beat.rounded(.down)) % 2 == 0 ? 1 : -1)
        let pelvis = CGPoint(x: sway, y: -5.0 + CGFloat(drop))
        let shoulder = pelvis + CGPoint(x: sway * 0.25, y: -3.2)
        let skull = shoulder + CGPoint(x: sway * 0.15, y: -1.35)

        var bones = Path()
        let leftFoot = CGPoint(x: -1.1, y: kick > 0 ? -0.9 * CGFloat(kick) : 0)
        let rightFoot = CGPoint(x: 1.1, y: kick < 0 ? 0.9 * CGFloat(kick) : 0)
        var joints: [CGPoint] = []
        for (hip, foot, bend) in [(pelvis + CGPoint(x: -0.55, y: 0), leftFoot, CGFloat(1)), (pelvis + CGPoint(x: 0.55, y: 0), rightFoot, CGFloat(-1))] {
            let knee = twoBoneJoint(from: hip, to: foot, upper: 2.6, lower: 2.6, bend: bend)
            bones.addLines([hip, knee, foot])
            joints.append(contentsOf: [knee, foot])
        }

        // Arms swing up and down on alternate beats; loud passages get both hands up.
        let loud = audio.level > 0.55
        let swingArm = cos(.pi * (beat + Double(index) * 0.5))
        let leftAngle = loud ? 2.6 + 0.3 * sin(2 * .pi * beat + Double(index)) : 1.45 + 0.95 * swingArm
        let rightAngle = loud ? 2.6 + 0.3 * sin(2 * .pi * beat + Double(index) + 1) : 1.45 - 0.95 * swingArm
        for (side, angle) in [(CGFloat(-1), leftAngle), (CGFloat(1), rightAngle)] {
            let shoulderPoint = shoulder + CGPoint(x: side * 1.0, y: 0.25)
            let hand = shoulderPoint + CGPoint(x: side * CGFloat(sin(angle)) * 3.0, y: CGFloat(cos(angle)) * 3.0)
            let elbow = twoBoneJoint(from: shoulderPoint, to: hand, upper: 1.7, lower: 1.6, bend: -side)
            bones.addLines([shoulderPoint, elbow, hand])
            bones.move(to: shoulder)
            bones.addLine(to: shoulderPoint)
            joints.append(contentsOf: [elbow, hand])
        }

        // Spine and ribs.
        bones.move(to: pelvis)
        bones.addLine(to: shoulder)
        for rib in 0..<3 {
            let y = shoulder.y + 0.55 + CGFloat(rib) * 0.6
            let x = pelvis.x + (shoulder.x - pelvis.x) * (1 - (y - shoulder.y) / (pelvis.y - shoulder.y))
            let width: CGFloat = 0.95 - CGFloat(rib) * 0.12
            bones.move(to: CGPoint(x: x - width, y: y + 0.15))
            bones.addQuadCurve(to: CGPoint(x: x + width, y: y + 0.15), control: CGPoint(x: x, y: y - 0.35))
        }

        var glow = g
        glow.addFilter(.shadow(color: HalloweenTheme.ghostGreen.opacity(0.25 + 0.35 * Double(audio.beatPulse)), radius: 0.8))
        glow.stroke(bones, with: .color(bone), style: boneStyle)
        var knobs = Path()
        for joint in joints { knobs.addPath(HalloweenTheme.disc(joint, 0.22)) }
        knobs.addPath(HalloweenTheme.ellipse(pelvis + CGPoint(x: 0, y: 0.1), 0.85, 0.42))
        glow.fill(knobs, with: .color(bone))

        // Skull, nodding along.
        var head = g
        head.translateBy(x: skull.x, y: skull.y)
        head.rotate(by: .radians(Double(sway) * 0.2))
        head.fill(HalloweenTheme.ellipse(.zero, 0.95, 1.0), with: .color(bone))
        head.fill(Path(roundedRect: CGRect(x: -0.55, y: 0.55, width: 1.1, height: 0.55), cornerRadius: 0.15), with: .color(bone))
        var face = Path()
        face.addPath(HalloweenTheme.ellipse(CGPoint(x: -0.35, y: -0.05), 0.24, 0.28))
        face.addPath(HalloweenTheme.ellipse(CGPoint(x: 0.35, y: -0.05), 0.24, 0.28))
        face.addLines([CGPoint(x: -0.08, y: 0.4), CGPoint(x: 0, y: 0.25), CGPoint(x: 0.08, y: 0.4)])
        face.closeSubpath()
        head.fill(face, with: .color(HalloweenTheme.silhouette))
        var teeth = Path()
        for tooth in -2...2 {
            teeth.move(to: CGPoint(x: CGFloat(tooth) * 0.2, y: 0.65))
            teeth.addLine(to: CGPoint(x: CGFloat(tooth) * 0.2, y: 1.0))
        }
        head.stroke(teeth, with: .color(HalloweenTheme.silhouette), lineWidth: 0.06)
    }
}
