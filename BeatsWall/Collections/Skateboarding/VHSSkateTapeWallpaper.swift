//
//  VHSSkateTapeWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// A skater looping a ledge line, played back off a worn 90s tape.
struct VHSSkateTapeWallpaper: View {
    let context: WallpaperContext

    /// One full line (ollie up, grind, kickflip out) every 8 beats.
    private static let beatsPerLine = 8.0

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            AudioTimeline(context: context) { frame in
                let glitch = 0.12 + 0.88 * pow(Double(frame.audio.beatPulse), 2) * (0.4 + 0.6 * Double(frame.audio.bass))
                Canvas { graphics, size in
                    drawScene(in: &graphics, size: size, frame: frame)
                    drawOverlay(in: &graphics, size: size, frame: frame, glitch: glitch)
                }
                .distortionEffect(ShaderLibrary.barrel(.float2(size), .float(0.14)), maxSampleOffset: .zero)
                .layerEffect(
                    ShaderLibrary.vhs(.float(frame.time), .float(glitch), .float2(size)),
                    maxSampleOffset: CGSize(width: 40, height: 0)
                )
                .overlay {
                    RadialGradient(colors: [.clear, .clear, .black.opacity(0.75)], center: .center, startRadius: 0, endRadius: max(size.width, size.height) * 0.62)
                }
            }
        }
    }

    private func drawScene(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let outline = unit * 0.005
        let groundY = size.height * 0.74

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x8FD3E8), Color(hex: 0xE9F4EE)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: groundY)
        ))

        // Back wall with a painted piece that pumps with the bass.
        let wallTop = size.height * 0.3
        let wall = Path(CGRect(x: -outline, y: wallTop, width: size.width + outline * 2, height: groundY - wallTop))
        graphics.fillOutlined(wall, Color(hex: 0xC9B8A6), outline: outline)
        var bricks = Path()
        let brickH = unit * 0.035
        var row = 0
        var y = wallTop + brickH
        while y < groundY {
            bricks.move(to: CGPoint(x: 0, y: y))
            bricks.addLine(to: CGPoint(x: size.width, y: y))
            var x = row % 2 == 0 ? 0 : brickH
            while x < size.width {
                bricks.move(to: CGPoint(x: x, y: y - brickH))
                bricks.addLine(to: CGPoint(x: x, y: y))
                x += brickH * 2
            }
            y += brickH
            row += 1
        }
        graphics.stroke(bricks, with: .color(Color(hex: 0xA8937F)), lineWidth: outline * 0.7)

        let pump = 1 + 0.05 * CGFloat(audio.bass)
        let blobs: [(CGFloat, CGFloat, CGFloat, Color)] = [(0.3, 0.47, 0.11, SkateTheme.pink), (0.48, 0.44, 0.13, SkateTheme.yellow), (0.67, 0.48, 0.1, SkateTheme.teal)]
        for (bx, by, br, color) in blobs {
            let r = unit * br * pump
            let rect = CGRect(x: size.width * bx - r * 1.3, y: size.height * by - r, width: r * 2.6, height: r * 2)
            graphics.fillOutlined(Path(roundedRect: rect, cornerRadius: r * 0.9), color, outline: outline * 1.5)
        }
        let tag = graphics.resolve(Text("BEATS").font(.system(size: unit * 0.1, weight: .black, design: .rounded)).italic().foregroundStyle(SkateTheme.ink))
        graphics.draw(tag, at: CGPoint(x: size.width * 0.49 + unit * 0.006, y: size.height * 0.455 + unit * 0.006))
        let tagFront = graphics.resolve(Text("BEATS").font(.system(size: unit * 0.1, weight: .black, design: .rounded)).italic().foregroundStyle(SkateTheme.offWhite))
        graphics.draw(tagFront, at: CGPoint(x: size.width * 0.49, y: size.height * 0.455))

        // Plaza ground and the ledge.
        graphics.fillOutlined(Path(CGRect(x: -outline, y: groundY, width: size.width + outline * 2, height: size.height)), SkateTheme.concrete, outline: outline)
        let ledgeStart = size.width * 0.36
        let ledgeEnd = size.width * 0.7
        let ledgeHeight = unit * 0.07
        let ledgeDepth = unit * 0.03
        var ledgeTop = Path()
        ledgeTop.addLines([
            CGPoint(x: ledgeStart, y: groundY - ledgeHeight), CGPoint(x: ledgeEnd, y: groundY - ledgeHeight),
            CGPoint(x: ledgeEnd + ledgeDepth, y: groundY - ledgeHeight + ledgeDepth), CGPoint(x: ledgeStart + ledgeDepth, y: groundY - ledgeHeight + ledgeDepth),
        ])
        ledgeTop.closeSubpath()
        let ledgeFace = Path(CGRect(x: ledgeStart + ledgeDepth, y: groundY - ledgeHeight + ledgeDepth, width: ledgeEnd - ledgeStart, height: ledgeHeight - ledgeDepth + unit * 0.01))
        graphics.fillOutlined(ledgeFace, SkateTheme.concreteShade, outline: outline)
        graphics.fillOutlined(ledgeTop, SkateTheme.concrete, outline: outline)
        var edge = Path()
        edge.addLines([CGPoint(x: ledgeStart + ledgeDepth, y: groundY - ledgeHeight + ledgeDepth), CGPoint(x: ledgeEnd + ledgeDepth, y: groundY - ledgeHeight + ledgeDepth)])
        graphics.stroke(edge, with: .color(SkateTheme.steel), style: SkateTheme.outline(unit * 0.006))

        // Skater: the line repeats every 8 beats.
        let line = audio.beatProgress(at: frame.time) / Self.beatsPerLine
        let t = line - line.rounded(.down)
        let x = (-0.1 + 1.2 * t) * size.width
        let takeoff = ledgeStart - unit * 0.14
        let landOn = ledgeStart + unit * 0.06
        let popOff = ledgeEnd + ledgeDepth
        let landOff = popOff + unit * 0.22
        let grindY = ledgeHeight - ledgeDepth * 0.5
        var height: CGFloat = 0
        var pose = SkaterPose()
        pose.crouch = 0.2
        pose.lean = 0.1
        var grinding = false

        if x > takeoff && x < landOn {
            let p = Double((x - takeoff) / (landOn - takeoff))
            height = grindY * CGFloat(p) + unit * 0.06 * CGFloat(sin(.pi * p))
            pose = SkateTrick.ollie.pose(progress: p, base: pose)
        } else if x >= landOn && x <= popOff {
            height = grindY
            grinding = true
            pose.crouch = 0.4
            pose.armsOut = 0.85
            pose.armSwing = sin(frame.time * 3) * 0.2
        } else if x > popOff && x < landOff {
            let p = Double((x - popOff) / (landOff - popOff))
            height = grindY * CGFloat(1 - p) + unit * 0.08 * CGFloat(sin(.pi * p))
            pose = SkateTrick.kickflip.pose(progress: p, base: pose)
        }

        let figureUnit = unit * 0.02
        let wheels = CGPoint(x: x, y: groundY - height)
        if grinding {
            // Sparks off the trucks, flaring on the beat.
            var sparks = Path()
            let count = 4 + Int(8 * audio.beatPulse)
            for index in 0..<count {
                let angle = Double.pi * (0.85 + 0.25 * hash01(index, Int(frame.time * 20)))
                let length = unit * 0.03 * CGFloat(0.4 + hash01(index, Int(frame.time * 20) + 1))
                let start = wheels + CGPoint(x: -figureUnit * 2.6, y: 0)
                sparks.move(to: start)
                sparks.addLine(to: start + CGPoint(x: cos(angle) * length, y: sin(angle) * length * 0.5))
            }
            graphics.stroke(sparks, with: .color(SkateTheme.yellow), style: SkateTheme.outline(unit * 0.003))
        }
        SkaterFigure.draw(
            in: graphics, at: wheels - CGPoint(x: 0, y: SkaterFigure.wheelBase * figureUnit),
            unit: figureUnit, pose: pose,
            palette: SkaterPalette(shirt: SkateTheme.pink, cap: SkateTheme.teal, deckBottom: SkateTheme.orange)
        )
    }

    private func drawOverlay(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame, glitch: Double) {
        let unit = min(size.width, size.height)
        let margin = unit * 0.07
        let font = Font.system(size: unit * 0.04, weight: .bold, design: .monospaced)
        let seconds = Int(frame.time) % 3600
        let timecode = String(format: "0:%02d:%02d", seconds / 60, seconds % 60)

        func label(_ text: String, _ point: CGPoint, _ anchor: UnitPoint) {
            let shadow = graphics.resolve(Text(text).font(font).foregroundStyle(.black.opacity(0.6)))
            graphics.draw(shadow, at: point + CGPoint(x: unit * 0.004, y: unit * 0.004), anchor: anchor)
            let front = graphics.resolve(Text(text).font(font).foregroundStyle(.white))
            graphics.draw(front, at: point, anchor: anchor)
        }
        label("PLAY ▶", CGPoint(x: margin, y: margin), .topLeading)
        label("SP", CGPoint(x: size.width - margin, y: margin), .topTrailing)
        label("JUN 14 1996", CGPoint(x: margin, y: size.height - margin), .bottomLeading)
        label(timecode, CGPoint(x: size.width - margin, y: size.height - margin), .bottomTrailing)
        if glitch > 0.6 {
            label("TRACKING", CGPoint(x: size.width / 2, y: size.height - margin), .bottom)
        }
    }
}
