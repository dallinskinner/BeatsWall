//
//  WhaleSongWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct WhaleSongWallpaper: View {
    let context: WallpaperContext
    @State private var song = WhaleSong()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                song.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(DeepSeaTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let unit = min(size.width, size.height)
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [DeepSeaTheme.shallow, DeepSeaTheme.midwater, DeepSeaTheme.deep]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        DeepSeaTheme.drawGodRays(in: &graphics, size: size, time: frame.time, intensity: 1.2)
        DeepSeaTheme.drawMarineSnow(in: &graphics, size: size, time: frame.time, count: context.isReduced ? 50 : 120, brightness: 0.35)

        // The whale glides across over about a minute, bobbing gently.
        let length = size.width * 0.62
        let cycle = (frame.time / 70).truncatingRemainder(dividingBy: 1)
        let head = CGPoint(
            x: -length * 0.2 + CGFloat(cycle) * (size.width + length * 1.2),
            y: size.height * 0.5 + unit * 0.03 * CGFloat(sin(frame.time * 0.3))
        )

        // Song: rings rippling out from the whale's head.
        var rings = graphics
        rings.blendMode = .plusLighter
        for ring in song.rings {
            let age = frame.time - ring.born
            let radius = unit * CGFloat(0.05 + age * 0.22)
            let opacity = max(0, 1 - age / 4) * ring.strength
            rings.stroke(DeepSeaTheme.disc(head + CGPoint(x: length * 0.02, y: 0), radius), with: .color(DeepSeaTheme.cyan.opacity(0.35 * opacity)), lineWidth: max(1, unit * 0.003))
        }

        drawWhale(in: &graphics, head: head, length: length, frame: frame)
        drawSchool(in: &graphics, size: size, unit: unit, frame: frame)
    }

    private func drawWhale(in graphics: inout GraphicsContext, head: CGPoint, length: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let height = length * 0.18
        // The tail beats slowly, once every four beats.
        let fluke = CGFloat(sin(audio.beatProgress(at: frame.time) * .pi / 2)) * height * 0.5
        let tailRoot = CGPoint(x: head.x - length * 0.82, y: head.y - height * 0.05)

        var body = Path()
        body.move(to: head)
        body.addCurve(to: CGPoint(x: head.x - length * 0.45, y: head.y - height * 0.55), control1: CGPoint(x: head.x - length * 0.02, y: head.y - height * 0.5), control2: CGPoint(x: head.x - length * 0.2, y: head.y - height * 0.62))
        body.addCurve(to: tailRoot + CGPoint(x: 0, y: fluke * 0.3 - height * 0.08), control1: CGPoint(x: head.x - length * 0.62, y: head.y - height * 0.5), control2: CGPoint(x: head.x - length * 0.75, y: head.y - height * 0.2))
        body.addLine(to: tailRoot + CGPoint(x: 0, y: fluke * 0.3 + height * 0.06))
        body.addCurve(to: CGPoint(x: head.x - length * 0.35, y: head.y + height * 0.5), control1: CGPoint(x: head.x - length * 0.7, y: head.y + height * 0.2), control2: CGPoint(x: head.x - length * 0.5, y: head.y + height * 0.48))
        body.addCurve(to: head, control1: CGPoint(x: head.x - length * 0.15, y: head.y + height * 0.52), control2: CGPoint(x: head.x - length * 0.01, y: head.y + height * 0.3))
        body.closeSubpath()

        var tail = Path()
        let tailTip = tailRoot + CGPoint(x: -length * 0.04, y: fluke)
        tail.move(to: tailRoot + CGPoint(x: 0, y: fluke * 0.3))
        tail.addQuadCurve(to: tailTip + CGPoint(x: -length * 0.08, y: -height * 0.45), control: tailTip + CGPoint(x: length * 0.01, y: -height * 0.3))
        tail.addQuadCurve(to: tailTip, control: tailTip + CGPoint(x: -length * 0.05, y: -height * 0.1))
        tail.addQuadCurve(to: tailTip + CGPoint(x: -length * 0.08, y: height * 0.45), control: tailTip + CGPoint(x: -length * 0.05, y: height * 0.1))
        tail.addQuadCurve(to: tailRoot + CGPoint(x: 0, y: fluke * 0.3), control: tailTip + CGPoint(x: length * 0.01, y: height * 0.3))
        tail.closeSubpath()

        var fin = Path()
        let finRoot = CGPoint(x: head.x - length * 0.22, y: head.y + height * 0.35)
        let finSwing = CGFloat(sin(frame.time * 0.8)) * height * 0.15
        fin.move(to: finRoot)
        fin.addQuadCurve(to: finRoot + CGPoint(x: -length * 0.2, y: height * 0.75 + finSwing), control: finRoot + CGPoint(x: -length * 0.05, y: height * 0.6))
        fin.addQuadCurve(to: finRoot + CGPoint(x: -length * 0.06, y: 0), control: finRoot + CGPoint(x: -length * 0.12, y: height * 0.4))
        fin.closeSubpath()

        let shade = Color(hex: 0x0B2236)
        graphics.fill(tail, with: .color(shade))
        graphics.fill(body, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x0A1C2E), Color(hex: 0x1C3E58)]),
            startPoint: CGPoint(x: head.x, y: head.y - height * 0.6), endPoint: CGPoint(x: head.x, y: head.y + height * 0.5)
        ))
        // Throat grooves and light from above.
        var clipped = graphics
        clipped.clip(to: body)
        var grooves = Path()
        for groove in 0..<6 {
            let y = head.y + height * (0.18 + 0.05 * CGFloat(groove))
            grooves.move(to: CGPoint(x: head.x - length * 0.02, y: y))
            grooves.addLine(to: CGPoint(x: head.x - length * 0.32, y: y + height * 0.06))
        }
        clipped.stroke(grooves, with: .color(Color(hex: 0x4F7A96).opacity(0.5)), lineWidth: max(1, length * 0.002))
        clipped.fill(body, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x9FE8FF).opacity(0.12), .clear]),
            startPoint: CGPoint(x: head.x, y: head.y - height * 0.6), endPoint: CGPoint(x: head.x, y: head.y)
        ))
        graphics.fill(fin, with: .color(Color(hex: 0x14324A)))
        graphics.fill(DeepSeaTheme.disc(CGPoint(x: head.x - length * 0.12, y: head.y + height * 0.02), length * 0.006), with: .color(.black.opacity(0.8)))
    }

    /// A school of small fish swirling around a wandering center.
    private func drawSchool(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let center = CGPoint(
            x: size.width * CGFloat(0.5 + 0.3 * sin(frame.time * 0.07)),
            y: size.height * CGFloat(0.25 + 0.1 * sin(frame.time * 0.11))
        )
        var fish = Path()
        let count = context.isReduced ? 30 : 70
        let swirl = song.swirl
        for index in 0..<count {
            let orbit = unit * CGFloat(0.04 + 0.12 * hash01(index, 1))
            let angle = swirl * (1.2 - 0.6 * hash01(index, 2)) + hash01(index, 3) * 2 * .pi
            let wobble = unit * 0.015 * CGFloat(sin(frame.time * 2 + Double(index)))
            let point = center + CGPoint(x: cos(angle) * (orbit + wobble), y: sin(angle) * (orbit + wobble) * 0.45)
            let heading = angle + .pi / 2
            let length = unit * 0.012
            let direction = CGPoint(x: cos(heading), y: sin(heading) * 0.45)
            let normal = CGPoint(x: -direction.y, y: direction.x)
            fish.move(to: point + direction * length)
            fish.addQuadCurve(to: point - direction * length, control: point + normal * (length * 0.5))
            fish.addLine(to: point - direction * (length * 1.5) + normal * (length * 0.4))
            fish.addLine(to: point - direction * (length * 1.5) - normal * (length * 0.4))
            fish.addLine(to: point - direction * length)
            fish.addQuadCurve(to: point + direction * length, control: point - normal * (length * 0.5))
        }
        graphics.fill(fish, with: .color(Color(hex: 0xBFE6F2).opacity(0.55 + 0.3 * Double(audio.treble))))
    }
}

/// Song rings sung with the melody, and the school's swirl.
private final class WhaleSong {
    struct Ring {
        var born: Double
        var strength: Double
    }

    private(set) var rings: [Ring] = []
    private(set) var swirl = 0.0
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()
    private var lastRing = -100.0

    func step(frame: AudioFrame) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        swirl += clock.deltaTime * (0.3 + 1.2 * Double(audio.level))
        let beat = beatEdge.isNewBeat(audio)
        if (beat && audio.mid > 0.35) || frame.time - lastRing > 3 {
            rings.append(Ring(born: frame.time, strength: 0.4 + 0.6 * Double(audio.mid)))
            lastRing = frame.time
        }
        rings.removeAll { frame.time - $0.born > 4 }
    }
}
