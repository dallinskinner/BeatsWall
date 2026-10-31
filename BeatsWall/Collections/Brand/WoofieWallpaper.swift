//
//  WoofieWallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Woofie, the BeatsWall speaker, dancing on a pixel dance floor.
struct WoofieWallpaper: View {
    let context: WallpaperContext
    @State private var scene = WoofieScene()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                scene.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(BrandTheme.grain(amount: 0.03))
    }

    // MARK: - Sprite

    /// The cabinet is 14×18 pixels with its corners rounded off; the legs hang below it.
    private static let cabinetWidth = 14
    private static let cabinetHeight = 18
    private static let spriteHeight = 20
    private static let cabinet = Color(hex: 0x2B1D5C)
    private static let armsDown = [(col: -1, row: 9), (col: -2, row: 10), (col: -3, row: 11), (col: 14, row: 9), (col: 15, row: 10), (col: 16, row: 11)]
    private static let armsUp = [(col: -1, row: 9), (col: -2, row: 8), (col: -3, row: 7), (col: -3, row: 6), (col: 14, row: 9), (col: 15, row: 8), (col: 16, row: 7), (col: 16, row: 6)]
    private static let legPoses = [[3, 4, 9, 10], [2, 3, 10, 11]]

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
        let bass = Double(audio.bass)
        let unit = min(size.width, size.height)
        let pixel = unit * 0.018
        let floorY = size.height * 0.72

        BrandTheme.backdrop(in: &graphics, size: size)
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [BrandTheme.magenta.opacity(0.12 + 0.12 * bass), .clear]),
            center: CGPoint(x: size.width / 2, y: floorY - unit * 0.15),
            startRadius: 0, endRadius: unit * 0.6
        ))

        drawSkyline(in: &graphics, size: size, floorY: floorY, pixel: pixel, audio: audio)
        drawDanceFloor(in: &graphics, size: size, floorY: floorY, pixel: pixel, audio: audio)
        drawNotes(in: &graphics, size: size, pixel: pixel, time: frame.time)

        // Hop off the floor on each beat, higher with more bass. Snapped to half pixels for a retro feel.
        let hopCurve = 4 * pulse * (1 - pulse)
        let hop = ((hopCurve * pixel * (1.5 + 3 * bass)) / (pixel * 0.5)).rounded() * pixel * 0.5
        let beatProgress = Double(audio.beatCount) + (1 - pulse)
        let sway = sin(.pi * beatProgress) * pixel * 0.8
        let squash = pow(pulse, 3)
        let scaleY = 1 - 0.12 * squash + 0.05 * hopCurve
        let scaleX = 1 + 0.08 * squash

        // Shadow shrinks as Woofie leaves the floor.
        let shadowWidth = pixel * 15 * (1 - 0.25 * hopCurve)
        graphics.fill(
            Path(ellipseIn: CGRect(x: size.width / 2 + sway - shadowWidth / 2, y: floorY - pixel * 0.5, width: shadowWidth, height: pixel * 1.4)),
            with: .color(.black.opacity(0.4))
        )

        let feet = CGPoint(x: size.width / 2 + sway, y: floorY - hop)
        func cell(_ col: Int, _ row: Int) -> CGRect {
            let width = pixel * scaleX
            let height = pixel * scaleY
            return CGRect(
                x: feet.x + (CGFloat(col) - CGFloat(Self.cabinetWidth) / 2) * width,
                y: feet.y + (CGFloat(row) - CGFloat(Self.spriteHeight)) * height,
                width: width + 0.5, height: height + 0.5
            )
        }

        // Cabinet, arms and legs.
        var body = Path()
        for row in 0..<Self.cabinetHeight {
            for col in 0..<Self.cabinetWidth {
                let isCorner = (row == 0 || row == Self.cabinetHeight - 1) && (col == 0 || col == Self.cabinetWidth - 1)
                if !isCorner { body.addRect(cell(col, row)) }
            }
        }
        // Arms go up on alternate bars once the music gets going.
        let armsUp = (audio.beatCount / 2) % 2 == 1 && audio.level > 0.45
        for arm in armsUp ? Self.armsUp : Self.armsDown {
            body.addRect(cell(arm.col, arm.row))
        }
        for col in Self.legPoses[audio.beatCount % 2] {
            body.addRect(cell(col, 18))
            body.addRect(cell(col, 19))
        }
        var glow = graphics
        glow.addFilter(.shadow(color: BrandTheme.magenta.opacity(0.45 + 0.35 * bass), radius: pixel * (1 + 2.5 * bass)))
        glow.fill(body, with: .color(Self.cabinet))

        // The woofer: surround, cone and dust cap, pumping out with the bass.
        let pump = 1 + 0.14 * bass + 0.08 * pulse
        var surround = Path()
        var cone = Path()
        var cap = Path()
        for row in 6..<Self.cabinetHeight - 1 {
            for col in 1..<Self.cabinetWidth - 1 {
                let distance = hypot(Double(col) - 6.5, Double(row) - 11.5) / pump
                if distance <= 1.6 {
                    cap.addRect(cell(col, row))
                } else if distance <= 4.1 {
                    cone.addRect(cell(col, row))
                } else if distance <= 5.1 {
                    surround.addRect(cell(col, row))
                }
            }
        }
        graphics.fill(surround, with: .color(BrandTheme.orange))
        graphics.fill(cone, with: .color(BrandTheme.magenta.mix(with: BrandTheme.plum, by: 0.35 - 0.3 * pulse)))
        graphics.fill(cap, with: .color(BrandTheme.yellow))

        // Eyes that look toward each other, with a blink every few seconds.
        let isBlinking = frame.time.truncatingRemainder(dividingBy: 3.7) < 0.13
        var whites = Path()
        var pupils = Path()
        for col in [3, 9] {
            if isBlinking {
                whites.addRect(cell(col, 3).union(cell(col + 1, 3)))
            } else {
                for row in 2...3 { whites.addRect(cell(col, row).union(cell(col + 1, row))) }
                pupils.addRect(cell(col == 3 ? 4 : 9, 3))
            }
        }
        graphics.fill(whites, with: .color(BrandTheme.glow))
        graphics.fill(pupils, with: .color(BrandTheme.ink))
    }

    /// The spectrum as faint stacked pixel blocks behind Woofie, in the icon's colors.
    private func drawSkyline(in graphics: inout GraphicsContext, size: CGSize, floorY: CGFloat, pixel: CGFloat, audio: AudioFeatures) {
        let count = audio.spectrum.count
        let columnWidth = size.width / CGFloat(count)
        let blockHeight = pixel * 1.6
        let maxBlocks = Int((floorY - size.height * 0.1) / blockHeight)
        for (index, value) in audio.spectrum.enumerated() {
            let filled = Int(Double(value) * Double(maxBlocks))
            var blocks = Path()
            var cap = Path()
            for block in 0..<filled {
                let rect = CGRect(
                    x: CGFloat(index) * columnWidth + pixel * 0.4,
                    y: floorY - CGFloat(block + 1) * blockHeight,
                    width: columnWidth - pixel * 0.8,
                    height: blockHeight - pixel * 0.4
                )
                if block == filled - 1 { cap.addRect(rect) } else { blocks.addRect(rect) }
            }
            let color = BrandTheme.gradient(Double(index) / Double(count - 1))
            graphics.fill(blocks, with: .color(color.opacity(0.08)))
            graphics.fill(cap, with: .color(color.opacity(0.25)))
        }
    }

    /// Tiles that light up in a new random pattern on every beat.
    private func drawDanceFloor(in graphics: inout GraphicsContext, size: CGSize, floorY: CGFloat, pixel: CGFloat, audio: AudioFeatures) {
        let tile = pixel * 3.4
        let gap = pixel * 0.45
        let columns = Int(size.width / tile) + 1
        let offsetX = (size.width - CGFloat(columns) * tile) / 2
        let pulse = Double(audio.beatPulse)
        var unlit = Path()
        var lit = Array(repeating: Path(), count: 3)
        for row in 0..<3 {
            for col in 0..<columns {
                let rect = CGRect(
                    x: offsetX + CGFloat(col) * tile + gap / 2,
                    y: floorY + pixel * 1.6 + CGFloat(row) * tile,
                    width: tile - gap, height: tile - gap
                )
                let roll = hash01(col + row * 997, audio.beatCount)
                if roll < 0.25 {
                    lit[Int(roll * 12)].addRect(rect)
                } else {
                    unlit.addRect(rect)
                }
            }
        }
        graphics.fill(unlit, with: .color(BrandTheme.glow.opacity(0.03)))
        for (index, path) in lit.enumerated() {
            graphics.fill(path, with: .color(BrandTheme.gradient(Double(index) / 2).opacity(0.1 + 0.5 * pulse)))
        }
    }

    private func drawNotes(in graphics: inout GraphicsContext, size: CGSize, pixel: CGFloat, time: Double) {
        let notePixel = pixel * 0.9
        let unit = min(size.width, size.height)
        for note in scene.notes {
            let age = time - note.born
            let fade = max(0, 1 - age / WoofieScene.noteLifetime)
            let origin = CGPoint(
                x: size.width / 2 + note.side * unit * (0.2 + 0.05 * note.seed) + sin(age * 3 + note.seed * 6) * pixel,
                y: size.height * 0.5 - age * unit * 0.12
            )
            var path = Path()
            path.addPixelSprite(Self.note, origin: origin, pixelWidth: notePixel)
            graphics.fill(path, with: .color(BrandTheme.gradient(note.seed).opacity(0.8 * fade)))
        }
    }
}

/// Music notes that float up from Woofie on the beat.
private final class WoofieScene {
    struct Note {
        var born: Double
        /// -1 for left of Woofie, 1 for right.
        var side: Double
        var seed: Double
    }

    static let noteLifetime = 2.6

    private(set) var notes: [Note] = []
    private var beatEdge = BeatEdge()

    func step(frame: AudioFrame) {
        if beatEdge.isNewBeat(frame.audio), frame.audio.beatCount % 2 == 0 {
            notes.append(Note(born: frame.time, side: Bool.random() ? -1 : 1, seed: .random(in: 0...1)))
        }
        notes.removeAll { frame.time - $0.born > Self.noteLifetime || frame.time < $0.born }
    }
}
