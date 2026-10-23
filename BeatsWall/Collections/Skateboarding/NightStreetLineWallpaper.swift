//
//  NightStreetLineWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct NightStreetLineWallpaper: View {
    let context: WallpaperContext
    @State private var scene = StreetScene()

    private static let windowLit = SkateTheme.yellow
    private static let windowDark = Color(hex: 0x262B50)
    private static let building = Color(hex: 0x1A1F40)

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                let unit = min(size.width, size.height)
                scene.step(frame: frame, unit: unit, skaterX: size.width * 0.3)
                draw(in: &graphics, size: size, unit: unit, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.03)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let outline = unit * 0.005
        let groundY = size.height * 0.8
        let distance = CGFloat(scene.distance)

        // Sky, stars and moon.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x0E1230), Color(hex: 0x2B2D5C)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: groundY)
        ))
        var stars = Path()
        for index in 0..<70 {
            let x = CGFloat(hash01(index, 1)) * size.width
            let y = CGFloat(hash01(index, 2)) * size.height * 0.5
            let r = unit * 0.0025 * CGFloat(0.6 + hash01(index, 3) * (0.6 + Double(audio.treble)))
            stars.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        graphics.fill(stars, with: .color(SkateTheme.offWhite.opacity(0.8)))
        let moonRadius = unit * 0.06
        let moon = CGPoint(x: size.width * 0.82, y: size.height * 0.17)
        graphics.fillOutlined(Path(ellipseIn: CGRect(x: moon.x - moonRadius, y: moon.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)), SkateTheme.offWhite, outline: outline)
        for (dx, dy, r) in [(-0.3, -0.2, 0.22), (0.3, 0.25, 0.16), (0.1, -0.45, 0.1)] {
            let c = moon + CGPoint(x: dx * moonRadius, y: dy * moonRadius)
            graphics.fill(Path(ellipseIn: CGRect(x: c.x - r * moonRadius, y: c.y - r * moonRadius, width: 2 * r * moonRadius, height: 2 * r * moonRadius)), with: .color(SkateTheme.concreteShade))
        }

        drawSkyline(in: &graphics, size: size, unit: unit, groundY: groundY, offset: distance * 0.15, audio: audio, outline: outline)
        drawStreetlights(in: &graphics, size: size, unit: unit, groundY: groundY, offset: distance * 0.6, audio: audio, outline: outline)

        // Sidewalk, curb and road.
        let curbY = groundY + unit * 0.07
        graphics.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: curbY - groundY)), with: .color(Color(hex: 0x5A5F7E)))
        graphics.fill(Path(CGRect(x: 0, y: curbY, width: size.width, height: unit * 0.02)), with: .color(Color(hex: 0x3E4262)))
        graphics.fill(Path(CGRect(x: 0, y: curbY + unit * 0.02, width: size.width, height: size.height)), with: .color(Color(hex: 0x24273D)))
        var lines = Path()
        lines.addLines([CGPoint(x: 0, y: groundY), CGPoint(x: size.width, y: groundY)])
        lines.move(to: CGPoint(x: 0, y: curbY))
        lines.addLine(to: CGPoint(x: size.width, y: curbY))
        let joint = unit * 0.16
        var x = -(distance.truncatingRemainder(dividingBy: joint))
        while x < size.width {
            lines.move(to: CGPoint(x: x, y: groundY))
            lines.addLine(to: CGPoint(x: x - unit * 0.02, y: curbY))
            x += joint
        }
        graphics.stroke(lines, with: .color(SkateTheme.ink), lineWidth: outline)
        var dashes = Path()
        let dash = unit * 0.2
        x = -(distance.truncatingRemainder(dividingBy: dash))
        let roadMid = (curbY + size.height) / 2 + unit * 0.02
        while x < size.width {
            dashes.addRect(CGRect(x: x, y: roadMid, width: dash * 0.5, height: unit * 0.008))
            x += dash
        }
        graphics.fill(dashes, with: .color(SkateTheme.yellow.opacity(0.8)))

        for obstacle in scene.obstacles {
            let screenX = scene.skaterX + CGFloat(obstacle.x) - distance
            guard screenX > -unit * 0.2, screenX < size.width + unit * 0.2 else { continue }
            drawObstacle(in: &graphics, kind: obstacle.kind, at: CGPoint(x: screenX, y: groundY), unit: unit, outline: outline)
        }

        drawSkater(in: &graphics, unit: unit, groundY: groundY, frame: frame)
    }

    private func drawSkyline(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, groundY: CGFloat, offset: CGFloat, audio: AudioFeatures, outline: CGFloat) {
        let slot = unit * 0.15
        let first = Int((offset / slot).rounded(.down)) - 1
        let count = Int(size.width / slot) + 3
        var buildings = Path()
        var lit = Path()
        var dark = Path()
        for index in first..<(first + count) {
            let width = slot * CGFloat(0.72 + 0.26 * hash01(index, 11))
            let height = size.height * CGFloat(0.16 + 0.3 * hash01(index, 12))
            let left = CGFloat(index) * slot - offset
            let rect = CGRect(x: left, y: groundY - height, width: width, height: height)
            buildings.addRect(rect)

            // Windows double as an equalizer for the spectrum bin under the building.
            let bin = min(max(Int((left + width / 2) / size.width * CGFloat(AudioFeatures.binCount)), 0), AudioFeatures.binCount - 1)
            let window = unit * 0.016
            let columns = max(Int(width / (window * 2)), 1)
            let rows = Int((height - window) / (window * 2))
            let litRows = Int((0.15 + 0.85 * Double(audio.spectrum[bin])) * Double(rows))
            let inset = (width - CGFloat(columns) * window * 2 + window) / 2
            for row in 0..<rows {
                for column in 0..<columns {
                    let windowRect = CGRect(
                        x: left + inset + CGFloat(column) * window * 2,
                        y: groundY - window * 2 - CGFloat(row) * window * 2,
                        width: window, height: window * 1.2
                    )
                    if row < litRows && hash01(index * 31 + column, row) > 0.2 {
                        lit.addRect(windowRect)
                    } else {
                        dark.addRect(windowRect)
                    }
                }
            }
        }
        graphics.fill(buildings, with: .color(Self.building))
        graphics.stroke(buildings, with: .color(SkateTheme.ink), lineWidth: outline)
        graphics.fill(dark, with: .color(Self.windowDark))
        graphics.fill(lit, with: .color(Self.windowLit.opacity(0.9)))
    }

    private func drawStreetlights(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, groundY: CGFloat, offset: CGFloat, audio: AudioFeatures, outline: CGFloat) {
        let spacing = unit * 0.6
        var x = spacing - offset.truncatingRemainder(dividingBy: spacing) - spacing
        let height = unit * 0.36
        while x < size.width + spacing {
            let head = CGPoint(x: x + unit * 0.05, y: groundY - height)
            var cone = Path()
            cone.move(to: head)
            cone.addLine(to: CGPoint(x: head.x - unit * 0.12, y: groundY))
            cone.addLine(to: CGPoint(x: head.x + unit * 0.12, y: groundY))
            cone.closeSubpath()
            graphics.fill(cone, with: .linearGradient(
                Gradient(colors: [SkateTheme.yellow.opacity(0.18 + 0.2 * Double(audio.level)), .clear]),
                startPoint: head, endPoint: CGPoint(x: head.x, y: groundY)
            ))
            var pole = Path()
            pole.addLines([CGPoint(x: x, y: groundY), CGPoint(x: x, y: head.y), head])
            graphics.stroke(pole, with: .color(SkateTheme.ink), style: SkateTheme.outline(unit * 0.008 + outline * 2))
            graphics.stroke(pole, with: .color(Color(hex: 0x4A5070)), style: SkateTheme.outline(unit * 0.008))
            let lamp = Path(roundedRect: CGRect(x: head.x - unit * 0.025, y: head.y - unit * 0.008, width: unit * 0.05, height: unit * 0.018), cornerRadius: unit * 0.006)
            graphics.fillOutlined(lamp, SkateTheme.yellow, outline: outline)
            x += spacing
        }
    }

    private func drawObstacle(in graphics: inout GraphicsContext, kind: Int, at base: CGPoint, unit: CGFloat, outline: CGFloat) {
        switch kind {
        case 0: // Traffic cone.
            let h = unit * 0.06
            var cone = Path()
            cone.addLines([base + CGPoint(x: -h * 0.35, y: 0), base + CGPoint(x: -h * 0.08, y: -h), base + CGPoint(x: h * 0.08, y: -h), base + CGPoint(x: h * 0.35, y: 0)])
            cone.closeSubpath()
            graphics.fillOutlined(cone, SkateTheme.orange, outline: outline)
            graphics.fill(Path(CGRect(x: base.x - h * 0.22, y: base.y - h * 0.6, width: h * 0.44, height: h * 0.16)), with: .color(SkateTheme.offWhite))
            graphics.fillOutlined(Path(CGRect(x: base.x - h * 0.45, y: base.y - h * 0.08, width: h * 0.9, height: h * 0.1)), SkateTheme.orange, outline: outline)
        case 1: // Flat rail.
            let length = unit * 0.16, h = unit * 0.04
            var rail = Path()
            rail.addLines([base + CGPoint(x: -length / 2 + h * 0.3, y: 0), base + CGPoint(x: -length / 2 + h * 0.3, y: -h)])
            rail.move(to: base + CGPoint(x: length / 2 - h * 0.3, y: 0))
            rail.addLine(to: base + CGPoint(x: length / 2 - h * 0.3, y: -h))
            rail.move(to: base + CGPoint(x: -length / 2, y: -h))
            rail.addLine(to: base + CGPoint(x: length / 2, y: -h))
            graphics.stroke(rail, with: .color(SkateTheme.ink), style: SkateTheme.outline(unit * 0.008 + outline * 2))
            graphics.stroke(rail, with: .color(SkateTheme.teal), style: SkateTheme.outline(unit * 0.008))
        default: // Wooden crate.
            let s = unit * 0.05
            let crate = Path(CGRect(x: base.x - s / 2, y: base.y - s, width: s, height: s))
            graphics.fillOutlined(crate, SkateTheme.wood, outline: outline)
            var slats = Path()
            slats.addLines([base + CGPoint(x: -s / 2, y: -s), base + CGPoint(x: s / 2, y: 0)])
            graphics.stroke(slats, with: .color(SkateTheme.ink), lineWidth: outline)
        }
    }

    private func drawSkater(in graphics: inout GraphicsContext, unit: CGFloat, groundY: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let figureUnit = unit * 0.022
        var pose = SkaterPose()
        pose.crouch = 0.15 + 0.2 * Double(audio.bass)
        pose.armSwing = sin(frame.time * 1.7) * 0.25
        pose.lean = 0.12
        var height: CGFloat = 0

        if let jump = scene.jump {
            let progress = min(max((frame.time - jump.start) / jump.duration, 0), 1)
            pose = jump.trick.pose(progress: progress, base: pose)
            height = CGFloat(jump.height * sin(.pi * progress))
        }

        let shadowWidth = figureUnit * 9 * (1 - 0.4 * height / (unit * 0.15))
        graphics.fill(
            Path(ellipseIn: CGRect(x: scene.skaterX - shadowWidth / 2, y: groundY - figureUnit * 0.3, width: shadowWidth, height: figureUnit * 0.8)),
            with: .color(.black.opacity(0.35))
        )
        SkaterFigure.draw(
            in: graphics,
            at: CGPoint(x: scene.skaterX, y: groundY - height - SkaterFigure.wheelBase * figureUnit),
            unit: figureUnit, pose: pose,
            palette: SkaterPalette(shirt: SkateTheme.teal, cap: SkateTheme.orange, deckBottom: SkateTheme.yellow)
        )
    }
}

/// Scroll distance, the skater's jumps and obstacles timed to arrive on future jumps.
private final class StreetScene {
    struct Jump {
        var start: Double
        var duration: Double
        var trick: SkateTrick
        var height: Double
    }

    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()
    private(set) var skaterX: CGFloat = 0
    private(set) var jump: Jump?
    /// World x positions; an obstacle is under the skater when `x == distance`.
    private(set) var obstacles: [(x: Double, kind: Int)] = []

    var distance: Double { clock.phase }

    func step(frame: AudioFrame, unit: CGFloat, skaterX: CGFloat) {
        let audio = frame.audio
        self.skaterX = skaterX
        let tempo = audio.bpm > 0 ? min(max((Double(audio.bpm) - 70) / 90, 0), 1) : 0.5
        let speed = Double(unit) * (0.25 + 0.25 * tempo + 0.1 * Double(audio.level))
        clock.advance(to: frame.time, speed: speed)

        // Ollie on every other beat; tricks when the music is loud.
        if beatEdge.isNewBeat(audio), audio.beatCount % 2 == 0 {
            let duration = min(0.55, audio.beatLength * 1.1)
            let strong = audio.bass > 0.55 && audio.level > 0.3
            jump = Jump(
                start: frame.time, duration: duration,
                trick: SkateTrick.forBeat(audio.beatCount, strong: strong),
                height: Double(unit) * (0.08 + 0.05 * Double(audio.bass))
            )
            // Place an obstacle so it passes under the apex of the jump two beats from now.
            if hash01(audio.beatCount, 23) < 0.65 {
                let lead = audio.beatLength * 2 + duration / 2
                obstacles.append((x: distance + speed * lead, kind: Int(hash01(audio.beatCount, 29) * 3)))
            }
        }
        if let current = jump, frame.time - current.start > current.duration {
            jump = nil
        }
        obstacles.removeAll { distance - $0.x > Double(skaterX + unit * 0.3) }
    }
}
