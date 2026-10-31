//
//  ConcertTheme.swift
//  BeatsWall
//

import SwiftUI

enum ConcertTheme {
    static let magenta = Color(hex: 0xFF2E88)
    static let violet = Color(hex: 0x8A4BFF)
    static let ice = Color(hex: 0x6FD3FF)
    static let laserGreen = Color(hex: 0x39FF6A)
    static let amber = Color(hex: 0xFFB23F)
    static let pyro = Color(hex: 0xFF6A1F)
    static let night = Color(hex: 0x07050D)
    static let stage = Color(hex: 0x0D0A14)
    static let crowd = Color(hex: 0x030206)

    /// Light colors that a show cycles through, one per bar.
    static let rig: [Color] = [magenta, ice, violet, amber, laserGreen]
    static let confetti: [Color] = [magenta, ice, amber, .white, violet]

    static func grain() -> Shader {
        ShaderLibrary.grain(.float(0.03))
    }

    /// The light color for a bar, so every fixture in the rig changes together.
    static func rigColor(bar: Int, offset: Int = 0) -> Color {
        rig[((bar + offset) % rig.count + rig.count) % rig.count]
    }

    static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func glow(in graphics: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        guard opacity > 0.005, radius > 0 else { return }
        graphics.fill(disc(center, radius), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    /// A band of fog that lights up wherever beams cross it.
    static func haze(in graphics: GraphicsContext, rect: CGRect, color: Color, opacity: Double) {
        graphics.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [color.opacity(0), color.opacity(opacity), color.opacity(opacity * 0.6), color.opacity(0)]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)
        ))
    }

    /// A spotlight cone through haze. `angle` 0 points straight down, positive swings right,
    /// and π points straight up. Draw into a `.plusLighter` context.
    static func beam(in graphics: GraphicsContext, from origin: CGPoint, angle: Double, length: CGFloat, spread: Double, color: Color, intensity: Double) {
        guard intensity > 0.01 else { return }
        func edge(_ offset: Double, _ scale: Double) -> CGPoint {
            origin + CGPoint(x: sin(angle + offset) * length * scale, y: cos(angle + offset) * length * scale)
        }
        let end = edge(0, 1)
        var cone = Path()
        cone.addLines([origin, edge(-spread, 1), edge(spread, 1)])
        cone.closeSubpath()
        graphics.fill(cone, with: .linearGradient(
            Gradient(colors: [color.opacity(0.5 * intensity), color.opacity(0.12 * intensity), color.opacity(0)]),
            startPoint: origin, endPoint: end
        ))
        var core = Path()
        core.addLines([origin, edge(-spread * 0.3, 0.9), edge(spread * 0.3, 0.9)])
        core.closeSubpath()
        graphics.fill(core, with: .linearGradient(
            Gradient(colors: [color.mix(with: .white, by: 0.5).opacity(0.5 * intensity), color.opacity(0)]),
            startPoint: origin, endPoint: end
        ))
        glow(in: graphics, at: origin, radius: length * 0.05, color: color.mix(with: .white, by: 0.6), opacity: intensity)
    }

    /// A thin laser line with a soft glow. Same angle convention as `beam`.
    static func laser(in graphics: GraphicsContext, from origin: CGPoint, angle: Double, length: CGFloat, color: Color, intensity: Double, width: CGFloat) {
        guard intensity > 0.01 else { return }
        var line = Path()
        line.addLines([origin, origin + CGPoint(x: sin(angle) * length, y: cos(angle) * length)])
        graphics.stroke(line, with: .color(color.opacity(0.12 * intensity)), style: StrokeStyle(lineWidth: width * 7, lineCap: .round))
        graphics.stroke(line, with: .color(color.opacity(0.4 * intensity)), style: StrokeStyle(lineWidth: width * 2.5, lineCap: .round))
        graphics.stroke(line, with: .color(color.mix(with: .white, by: 0.45).opacity(intensity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// A white flash over everything.
    static func strobe(in graphics: GraphicsContext, size: CGSize, amount: Double) {
        guard amount > 0.01 else { return }
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(min(amount, 1) * 0.4)))
    }

    /// One row of the crowd in silhouette: heads, shoulders and raised hands that wave in
    /// time. `handsUp` is the share of people with a hand in the air and `jump` the share
    /// who bounce on each beat. Returns where the raised hands are, for phone lights.
    @discardableResult
    static func crowd(
        in graphics: GraphicsContext, size: CGSize, unit: CGFloat, baseline: CGFloat, scale: CGFloat, count: Int,
        seed: Int, color: Color, audio: AudioFeatures, beat: Double, handsUp: Double, jump: Double
    ) -> [CGPoint] {
        var bodies = Path()
        var arms = Path()
        var hands: [CGPoint] = []
        let spacing = (size.width + unit * 0.2) / CGFloat(count)
        let pulse = Double(audio.beatPulse)
        for index in 0..<count {
            let s = unit * scale * CGFloat(0.85 + 0.3 * hash01(index, seed))
            let x = -unit * 0.1 + spacing * (CGFloat(index) + 0.5 + CGFloat(hash01(index, seed + 1) - 0.5) * 0.7)
            let jumps = hash01(index, audio.beatCount &+ seed) < jump
            let bob = -s * CGFloat(0.09 * pulse * (jumps ? 1 : 0.25))
            let headY = baseline - s * 0.62 + bob
            bodies.addPath(disc(CGPoint(x: x, y: headY), s * 0.11))
            bodies.addRoundedRect(in: CGRect(x: x - s * 0.24, y: baseline - s * 0.47 + bob, width: s * 0.48, height: s * 0.7), cornerSize: CGSize(width: s * 0.16, height: s * 0.16))

            guard hash01(index, seed + 2) < handsUp else { continue }
            let both = hash01(index, seed + 3) < 0.35
            let wave = sin(beat * .pi + Double(index) * 0.9)
            for side in both ? [-1.0, 1.0] : [hash01(index, seed + 4) < 0.5 ? -1.0 : 1.0] {
                let shoulder = CGPoint(x: x + s * 0.17 * side, y: baseline - s * 0.4 + bob)
                let hand = shoulder + CGPoint(x: s * CGFloat(0.1 * side + 0.07 * wave), y: -s * CGFloat(0.5 + 0.06 * pulse))
                let elbow = shoulder + CGPoint(x: s * CGFloat(0.1 * side), y: -s * 0.25)
                arms.move(to: shoulder)
                arms.addQuadCurve(to: hand, control: elbow)
                bodies.addPath(disc(hand, s * 0.05))
                hands.append(hand)
            }
        }
        graphics.stroke(arms, with: .color(color), style: StrokeStyle(lineWidth: unit * scale * 0.08, lineCap: .round))
        graphics.fill(bodies, with: .color(color))
        return hands
    }

    /// Confetti fired from `origin`, `age` seconds ago. It flies out fast, then flutters down.
    static func confetti(in graphics: GraphicsContext, from origin: CGPoint, angle: Double, age: Double, unit: CGFloat, count: Int, seed: Int) {
        guard age >= 0, age < 7 else { return }
        let fade = 1 - smoothstep(5, 7, age)
        var pieces = Array(repeating: Path(), count: confetti.count)
        let reach = (1 - exp(-3 * age)) / 3
        for index in 0..<count {
            let direction = angle + (hash01(index, seed) - 0.5) * 0.9
            let speed = unit * CGFloat(1.6 + 1.4 * hash01(index, seed + 1))
            let flutter = sin(age * (3 + 2 * hash01(index, seed + 2)) + Double(index))
            let point = origin + CGPoint(
                x: sin(direction) * speed * CGFloat(reach) + unit * 0.03 * CGFloat(flutter) * CGFloat(min(age, 1)),
                y: -cos(direction) * speed * CGFloat(reach) + unit * CGFloat(0.07 + 0.04 * hash01(index, seed + 3)) * CGFloat(age)
            )
            let side = unit * 0.009
            let flip = CGFloat(abs(cos(age * 7 + Double(index))))
            let rect = CGRect(x: -side / 2, y: -side * 0.3, width: side, height: side * 0.6 * max(flip, 0.15))
            let transform = CGAffineTransform(translationX: point.x, y: point.y).rotated(by: age * 4 + Double(index))
            pieces[index % pieces.count].addPath(Path(rect).applying(transform))
        }
        for (index, path) in pieces.enumerated() {
            graphics.fill(path, with: .color(confetti[index].opacity(0.95 * fade)))
        }
    }

    /// Sparks pouring down from `top` across `span`, like a curtain of pyro gerbs.
    static func sparkRain(in graphics: GraphicsContext, span: ClosedRange<CGFloat>, top: CGFloat, floor: CGFloat, age: Double, unit: CGFloat, count: Int, intensity: Double) {
        guard intensity > 0.01 else { return }
        var trails = Path()
        let fall = floor - top
        for index in 0..<count {
            let cycle = age * (0.9 + 0.6 * hash01(index, 31)) + hash01(index, 32)
            let progress = cycle - cycle.rounded(.down)
            let x = span.lowerBound + (span.upperBound - span.lowerBound) * CGFloat(hash01(index, 33))
            let y = top + fall * CGFloat(progress * progress)
            let drift = unit * 0.02 * CGFloat(progress) * CGFloat(hash01(index, 34) - 0.5)
            trails.move(to: CGPoint(x: x + drift, y: y))
            trails.addLine(to: CGPoint(x: x + drift * 0.8, y: y - unit * CGFloat(0.015 + 0.04 * progress)))
        }
        graphics.stroke(trails, with: .color(amber.mix(with: .white, by: 0.4).opacity(0.9 * intensity)), style: StrokeStyle(lineWidth: max(1, unit * 0.0025), lineCap: .round))
    }

    /// A firework burst `age` seconds after it opened.
    static func firework(in graphics: GraphicsContext, at center: CGPoint, age: Double, radius: CGFloat, color: Color, seed: Int, count: Int) {
        guard age >= 0, age < 2.2 else { return }
        let fade = 1 - smoothstep(0.6, 2.2, age)
        let spread = radius * CGFloat(1 - exp(-4 * age))
        let droop = radius * 0.25 * CGFloat(age * age)
        var trails = Path()
        var tips = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi + hash01(seed, index) * 0.2
            let reach = spread * CGFloat(0.8 + 0.2 * hash01(index, seed))
            let tip = center + CGPoint(x: cos(angle) * reach, y: sin(angle) * reach + droop)
            let tail = center + CGPoint(x: cos(angle) * reach * 0.7, y: sin(angle) * reach * 0.7 + droop * 0.6)
            trails.move(to: tail)
            trails.addLine(to: tip)
            tips.addPath(disc(tip, radius * 0.018))
        }
        graphics.stroke(trails, with: .color(color.opacity(0.55 * fade)), style: StrokeStyle(lineWidth: radius * 0.012, lineCap: .round))
        graphics.fill(tips, with: .color(color.mix(with: .white, by: 0.5).opacity(fade)))
        glow(in: graphics, at: center, radius: radius * 1.2, color: color, opacity: 0.35 * fade * (1 - smoothstep(0, 0.8, age)))
    }
}

/// Follows the shape of the song, not just the beat: how loud it is right now, whether it's
/// building, and the moment it drops. Hold one per wallpaper in `@State`.
final class HypeMeter {
    /// 0...1, the overall energy right now, smoothed.
    private(set) var energy = 0.0
    /// 0...1, rises while the song climbs out of a quieter stretch and resets on a drop.
    private(set) var build = 0.0
    /// 1 the moment the song drops, decaying over a couple of seconds.
    private(set) var dropPulse = 0.0
    private(set) var secondsSinceDrop = Double.infinity
    /// Increments on every drop, for picking a new look each time.
    private(set) var dropCount = 0

    private var fast = 0.0
    private var slow = 0.0
    /// The quietest the song has been lately; creeps back up so old lulls are forgotten.
    private var valley = 0.0
    private var lastTime: Double?
    private var beats = BeatEdge()
    private var loudBeats = 0

    func update(time: Double, audio: AudioFeatures) {
        let delta = lastTime.map { min(max(time - $0, 0), 0.1) } ?? 0
        lastTime = time
        let level = 0.5 * Double(audio.level) + 0.5 * Double(audio.bass)
        fast += (level - fast) * (1 - exp(-delta * 5))
        slow += (level - slow) * (1 - exp(-delta * 0.35))
        valley = min(fast, valley + delta * 0.04)
        energy = smoothstep(0.08, 0.75, fast)
        secondsSinceDrop += delta
        dropPulse = secondsSinceDrop.isFinite ? exp(-secondsSinceDrop * 1.2) : 0

        let climbing = smoothstep(0.03, 0.25, fast - valley)
        build += ((secondsSinceDrop < 6 ? 0 : climbing) - build) * (1 - exp(-delta * 0.8))

        guard beats.isNewBeat(audio) else { return }
        loudBeats = energy > 0.55 ? loudBeats + 1 : 0
        let barLength = audio.beatLength * 4
        let coolingDown = secondsSinceDrop < barLength * 4
        // A real drop: a hard jump out of a lull. Otherwise a long loud stretch gets a
        // "moment" every 16 beats so the show never stays flat.
        let isDrop = fast > slow + 0.12 && fast - valley > 0.22 && audio.bass > 0.5
        let isMoment = loudBeats >= 16 && secondsSinceDrop > barLength * 8
        if !coolingDown, isDrop || isMoment {
            secondsSinceDrop = 0
            dropPulse = 1
            dropCount += 1
            build = 0
            loudBeats = 0
            valley = fast
        }
    }
}
