//
//  ClawdWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Clawd, the Claude Code mascot, dancing on a pixel dance floor.
struct ClawdWallpaper: View {
    let context: WallpaperContext
    @State private var scene = ClawdScene()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                scene.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ClaudeTheme.grain(amount: 0.03))
    }

    // MARK: - Sprites

    /// Traced from the Claude Code banner (`▐▛███▜▌` / `▝▜█████▛▘` / `▘▘ ▝▝`). Each terminal
    /// quadrant block is one pixel, so pixels are twice as tall as they are wide.
    private static let body = [
        "...############...",
        "...##.######.##...",
        "...############...",
        "...############...",
    ]
    private static let eyes = [(col: 5, row: 1), (col: 12, row: 1)]
    private static let armsDown = [(col: 1, row: 2), (col: 2, row: 2), (col: 15, row: 2), (col: 16, row: 2)]
    private static let armsUp = [(col: 2, row: 1), (col: 1, row: 0), (col: 15, row: 1), (col: 16, row: 0)]
    private static let legPoses = [[4, 6, 11, 13], [3, 5, 12, 14]]
    private static let spriteWidth = 18
    private static let spriteHeight = 5

    private static let note = [
        "..###",
        "..#.#",
        "..#..",
        "..#..",
        "###..",
        "###..",
    ]

    // MARK: - Drawing

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let pulse = Double(audio.beatPulse)
        let unit = min(size.width, size.height)
        let pixel = unit * 0.024
        let floorY = size.height * 0.68

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [ClaudeTheme.charcoal, ClaudeTheme.warmDark, ClaudeTheme.ink]),
            center: CGPoint(x: size.width / 2, y: floorY - unit * 0.1),
            startRadius: 0, endRadius: max(size.width, size.height) * 0.75
        ))

        drawSkyline(in: &graphics, size: size, floorY: floorY, pixel: pixel, audio: audio)
        drawDanceFloor(in: &graphics, size: size, floorY: floorY, pixel: pixel, audio: audio)
        drawNotes(in: &graphics, size: size, pixel: pixel, time: frame.time)

        // Hop off the floor on each beat, higher with more bass. Snapped to half pixels for a retro feel.
        let hopCurve = 4 * pulse * (1 - pulse)
        let hop = ((hopCurve * pixel * (1.5 + 3 * Double(audio.bass))) / (pixel * 0.5)).rounded() * pixel * 0.5
        let beatProgress = Double(audio.beatCount) + (1 - pulse)
        let sway = sin(.pi * beatProgress) * pixel * 0.8
        let squash = pow(pulse, 3)
        let scaleY = 1 - 0.14 * squash + 0.06 * hopCurve
        let scaleX = 1 + 0.1 * squash

        // Shadow shrinks as Clawd leaves the floor.
        let shadowWidth = pixel * 15 * (1 - 0.25 * hopCurve)
        graphics.fill(
            Path(ellipseIn: CGRect(x: size.width / 2 + sway - shadowWidth / 2, y: floorY - pixel * 0.5, width: shadowWidth, height: pixel * 1.4)),
            with: .color(.black.opacity(0.35))
        )

        let feet = CGPoint(x: size.width / 2 + sway, y: floorY - hop)
        func cell(_ col: Int, _ row: Int) -> CGRect {
            let width = pixel * scaleX
            let height = pixel * 2 * scaleY
            return CGRect(
                x: feet.x + (CGFloat(col) - CGFloat(Self.spriteWidth) / 2) * width,
                y: feet.y + (CGFloat(row) - CGFloat(Self.spriteHeight)) * height,
                width: width + 0.5, height: height + 0.5
            )
        }

        var sprite = Path()
        for (row, line) in Self.body.enumerated() {
            for (col, character) in line.enumerated() where character == "#" {
                sprite.addRect(cell(col, row))
            }
        }
        // Arms go up on alternate bars once the music gets going.
        let armsUp = (audio.beatCount / 2) % 2 == 1 && audio.level > 0.45
        for arm in armsUp ? Self.armsUp : Self.armsDown {
            sprite.addRect(cell(arm.col, arm.row))
        }
        for col in Self.legPoses[audio.beatCount % 2] {
            sprite.addRect(cell(col, 4))
        }

        var glow = graphics
        glow.addFilter(.shadow(color: ClaudeTheme.terracotta.opacity(0.35 + 0.35 * Double(audio.bass)), radius: pixel * (1 + 2 * Double(audio.bass))))
        glow.fill(sprite, with: .color(ClaudeTheme.terracotta))

        // Blink every few seconds.
        let isBlinking = frame.time.truncatingRemainder(dividingBy: 3.7) < 0.13
        if !isBlinking {
            var eyes = Path()
            for eye in Self.eyes { eyes.addRect(cell(eye.col, eye.row)) }
            graphics.fill(eyes, with: .color(ClaudeTheme.ink))
        }
    }

    /// The spectrum as faint stacked pixel blocks behind Clawd.
    private func drawSkyline(in graphics: inout GraphicsContext, size: CGSize, floorY: CGFloat, pixel: CGFloat, audio: AudioFeatures) {
        let count = audio.spectrum.count
        let columnWidth = size.width / CGFloat(count)
        let blockHeight = pixel * 1.2
        let maxBlocks = Int((floorY - size.height * 0.1) / blockHeight)
        var blocks = Path()
        var caps = Path()
        for (index, value) in audio.spectrum.enumerated() {
            let filled = Int(Double(value) * Double(maxBlocks))
            for block in 0..<filled {
                let rect = CGRect(
                    x: CGFloat(index) * columnWidth + pixel * 0.3,
                    y: floorY - CGFloat(block + 1) * blockHeight,
                    width: columnWidth - pixel * 0.6,
                    height: blockHeight - pixel * 0.3
                )
                if block == filled - 1 { caps.addRect(rect) } else { blocks.addRect(rect) }
            }
        }
        graphics.fill(blocks, with: .color(ClaudeTheme.terracotta.opacity(0.08)))
        graphics.fill(caps, with: .color(ClaudeTheme.terracotta.opacity(0.22)))
    }

    /// Tiles that light up in a new random pattern on every beat.
    private func drawDanceFloor(in graphics: inout GraphicsContext, size: CGSize, floorY: CGFloat, pixel: CGFloat, audio: AudioFeatures) {
        let tile = pixel * 2.6
        let gap = pixel * 0.35
        let columns = Int(size.width / tile) + 1
        let offsetX = (size.width - CGFloat(columns) * tile) / 2
        let pulse = Double(audio.beatPulse)
        var unlit = Path()
        var lit = Path()
        for row in 0..<3 {
            for col in 0..<columns {
                let rect = CGRect(
                    x: offsetX + CGFloat(col) * tile + gap / 2,
                    y: floorY + pixel * 1.2 + CGFloat(row) * tile,
                    width: tile - gap, height: tile - gap
                )
                if hash(col + row * 997, audio.beatCount) < 0.25 {
                    lit.addRect(rect)
                } else {
                    unlit.addRect(rect)
                }
            }
        }
        graphics.fill(unlit, with: .color(ClaudeTheme.cream.opacity(0.025)))
        graphics.fill(lit, with: .color(ClaudeTheme.terracotta.opacity(0.08 + 0.45 * pulse)))
    }

    private func drawNotes(in graphics: inout GraphicsContext, size: CGSize, pixel: CGFloat, time: Double) {
        let notePixel = pixel * 0.7
        let unit = min(size.width, size.height)
        for note in scene.notes {
            let age = time - note.born
            let fade = max(0, 1 - age / ClawdScene.noteLifetime)
            let origin = CGPoint(
                x: size.width / 2 + note.side * unit * (0.2 + 0.05 * note.seed) + sin(age * 3 + note.seed * 6) * pixel,
                y: size.height * 0.56 - age * unit * 0.12
            )
            var path = Path()
            for (row, line) in Self.note.enumerated() {
                for (col, character) in line.enumerated() where character == "#" {
                    path.addRect(CGRect(x: origin.x + CGFloat(col) * notePixel, y: origin.y + CGFloat(row) * notePixel, width: notePixel + 0.5, height: notePixel + 0.5))
                }
            }
            let color = note.seed > 0.5 ? ClaudeTheme.cream : ClaudeTheme.terracotta
            graphics.fill(path, with: .color(color.opacity(0.75 * fade)))
        }
    }

    private func hash(_ a: Int, _ b: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663)
        x ^= x >> 13
        x &*= 0x5bd1_e995
        x ^= x >> 15
        return Double(x % 1000) / 1000
    }
}

/// Music notes that float up from Clawd on the beat.
private final class ClawdScene {
    struct Note {
        var born: Double
        /// -1 for left of Clawd, 1 for right.
        var side: Double
        var seed: Double
    }

    static let noteLifetime = 2.6

    private(set) var notes: [Note] = []
    private var lastBeatCount: Int?

    func step(frame: AudioFrame) {
        let beatCount = frame.audio.beatCount
        if let lastBeatCount, beatCount != lastBeatCount, beatCount % 2 == 0 {
            notes.append(Note(born: frame.time, side: Bool.random() ? -1 : 1, seed: .random(in: 0...1)))
        }
        lastBeatCount = beatCount
        notes.removeAll { frame.time - $0.born > Self.noteLifetime || frame.time < $0.born }
    }
}
