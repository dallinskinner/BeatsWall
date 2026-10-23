//
//  StarShooterWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct StarShooterWallpaper: View {
    let context: WallpaperContext
    @State private var game = ShooterGame()

    static let columns = 8
    static let rows = 4
    private static let rowColors = [ArcadeTheme.pink, ArcadeTheme.cyan, ArcadeTheme.green, ArcadeTheme.yellow]
    private static let ship = [
        ".....#.....",
        "....###....",
        "....#C#....",
        ".#..###..#.",
        ".#.#####.#.",
        "###########",
        "####R#R####",
        "#..R...R..#",
    ]

    var body: some View {
        GeometryReader { geometry in
            let pixel = ArcadeTheme.pixel(for: geometry.size, across: 170)
            AudioTimeline(context: context) { frame in
                Canvas { graphics, size in
                    let layout = Layout(size: size, pixel: pixel)
                    game.step(frame: frame, layout: layout)
                    draw(in: &graphics, size: size, layout: layout, frame: frame)
                }
                .colorEffect(ArcadeTheme.crt(time: frame.time, pixel: pixel))
            }
        }
    }

    struct Layout {
        let size: CGSize
        let pixel: CGFloat
        var spacingX: CGFloat { pixel * 14 }
        var spacingY: CGFloat { pixel * 11 }
        var shipY: CGFloat { size.height - pixel * 22 }

        func invader(column: Int, row: Int, beat: Int, descent: CGFloat) -> CGPoint {
            // Classic march: a few steps sideways per beat, back and forth.
            let march = [0, 1, 2, 3, 2, 1, 0, -1, -2, -3, -2, -1]
            let offset = CGFloat(march[((beat % march.count) + march.count) % march.count]) * pixel * 3
            let left = size.width / 2 - spacingX * CGFloat(StarShooterWallpaper.columns - 1) / 2
            return CGPoint(x: left + CGFloat(column) * spacingX + offset, y: size.height * 0.14 + CGFloat(row) * spacingY + descent)
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, layout: Layout, frame: AudioFrame) {
        let audio = frame.audio
        let pixel = layout.pixel
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ArcadeTheme.black))

        // Three layers of stars falling past.
        for layer in 0..<3 {
            var stars = Path()
            let speed = Double(layer + 1) * size.height * 0.05
            for index in 0..<(30 + layer * 20) {
                let y = (CGFloat(hash01(index, layer)) * size.height + CGFloat(game.travel * speed)).truncatingRemainder(dividingBy: size.height)
                let x = CGFloat(hash01(index, layer + 10)) * size.width
                stars.addRect(CGRect(x: ArcadeTheme.snap(x, to: pixel), y: ArcadeTheme.snap(y, to: pixel), width: pixel * CGFloat(layer == 2 ? 2 : 1), height: pixel * CGFloat(1 + layer)))
            }
            graphics.fill(stars, with: .color(ArcadeTheme.white.opacity(0.3 + 0.25 * Double(layer))))
        }

        for row in 0..<Self.rows {
            let sprite = (row % 2 == 0 ? ArcadeTheme.bugA : ArcadeTheme.bugB)[audio.beatCount % 2]
            for column in 0..<Self.columns where game.alive[row][column] {
                let point = layout.invader(column: column, row: row, beat: audio.beatCount, descent: game.descent(beat: audio.beatCount, pixel: pixel))
                ArcadeTheme.drawSprite(sprite, palette: ["#": Self.rowColors[row]], origin: CGPoint(x: ArcadeTheme.snap(point.x - pixel * 4, to: pixel), y: ArcadeTheme.snap(point.y - pixel * 4, to: pixel)), pixel: pixel, in: graphics)
            }
        }

        var bullets = Path()
        for bullet in game.bullets {
            bullets.addRect(CGRect(x: ArcadeTheme.snap(bullet.x, to: pixel), y: ArcadeTheme.snap(bullet.y, to: pixel), width: pixel, height: pixel * 4))
        }
        graphics.fill(bullets, with: .color(ArcadeTheme.white))

        for explosion in game.explosions {
            let age = frame.time - explosion.time
            var shards = Path()
            for index in 0..<8 {
                let angle = Double(index) / 8 * 2 * .pi
                let distance = CGFloat(age) * pixel * 40
                let point = explosion.point + CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
                shards.addRect(CGRect(x: ArcadeTheme.snap(point.x, to: pixel), y: ArcadeTheme.snap(point.y, to: pixel), width: pixel * 2, height: pixel * 2))
            }
            graphics.fill(shards, with: .color(explosion.color.opacity(max(0, 1 - age / 0.45))))
        }

        let shipOrigin = CGPoint(x: ArcadeTheme.snap(game.shipX - pixel * 5.5, to: pixel), y: ArcadeTheme.snap(layout.shipY, to: pixel))
        ArcadeTheme.drawSprite(Self.ship, palette: ["#": ArcadeTheme.white, "C": ArcadeTheme.cyan, "R": ArcadeTheme.red.opacity(0.4 + 0.6 * Double(audio.bass))], origin: shipOrigin, pixel: pixel, in: graphics)

        // Ground line and HUD.
        graphics.fill(Path(CGRect(x: 0, y: size.height - pixel * 10, width: size.width, height: pixel)), with: .color(ArcadeTheme.green))
        let font = Font.system(size: pixel * 6, weight: .heavy, design: .monospaced)
        let score = graphics.resolve(Text(String(format: "SCORE %06d", game.score)).font(font).foregroundStyle(ArcadeTheme.white))
        graphics.draw(score, at: CGPoint(x: pixel * 8, y: pixel * 6), anchor: .topLeading)
        let wave = graphics.resolve(Text("WAVE \(game.wave)").font(font).foregroundStyle(ArcadeTheme.yellow))
        graphics.draw(wave, at: CGPoint(x: size.width - pixel * 8, y: pixel * 6), anchor: .topTrailing)
        for life in 0..<3 {
            ArcadeTheme.drawSprite(Self.ship, palette: ["#": ArcadeTheme.green, "C": ArcadeTheme.green, "R": ArcadeTheme.green], origin: CGPoint(x: pixel * (8 + CGFloat(life) * 14), y: size.height - pixel * 8.5), pixel: max(1, pixel / 2), in: graphics)
        }
    }
}

/// The invasion: formation state, bullets fired on the beat and explosions.
private final class ShooterGame {
    struct Bullet {
        var x: CGFloat
        var y: CGFloat
        var column: Int
        var row: Int
    }

    struct Explosion {
        var point: CGPoint
        var time: Double
        var color: Color
    }

    private(set) var alive = Array(repeating: Array(repeating: true, count: StarShooterWallpaper.columns), count: StarShooterWallpaper.rows)
    private(set) var bullets: [Bullet] = []
    private(set) var explosions: [Explosion] = []
    private(set) var shipX: CGFloat = 0
    private(set) var score = 0
    private(set) var wave = 1
    private(set) var travel = 0.0
    private var waveStart: Int?
    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()
    private var targetColumn = 0

    func descent(beat: Int, pixel: CGFloat) -> CGFloat {
        CGFloat(min(max(beat - (waveStart ?? beat), 0) / 12, 6)) * pixel * 4
    }

    func step(frame: AudioFrame, layout: StarShooterWallpaper.Layout) {
        let audio = frame.audio
        clock.advance(to: frame.time)
        let dt = clock.deltaTime
        travel += dt * (0.4 + 2.5 * Double(audio.level))
        if waveStart == nil { waveStart = audio.beatCount; shipX = layout.size.width / 2 }

        let aliveCount = alive.joined().filter { $0 }.count
        if beatEdge.isNewBeat(audio) {
            if aliveCount == 0 || audio.beatCount - (waveStart ?? 0) > 96 {
                alive = Array(repeating: Array(repeating: true, count: StarShooterWallpaper.columns), count: StarShooterWallpaper.rows)
                waveStart = audio.beatCount
                wave += 1
            } else if let target = pickTarget(layout: layout, beat: audio.beatCount) {
                bullets.append(Bullet(x: shipX, y: layout.shipY, column: target.column, row: target.row))
            }
        }

        // The ship glides under its next target.
        let targetX = layout.invader(column: targetColumn, row: 0, beat: audio.beatCount, descent: 0).x
        shipX += (targetX - shipX) * CGFloat(min(1, dt * 3))

        let descent = descent(beat: audio.beatCount, pixel: layout.pixel)
        for index in bullets.indices {
            bullets[index].y -= CGFloat(dt) * layout.size.height * 1.3
        }
        bullets.removeAll { bullet in
            let target = layout.invader(column: bullet.column, row: bullet.row, beat: audio.beatCount, descent: descent)
            if alive[bullet.row][bullet.column], bullet.y <= target.y + layout.pixel * 3 {
                alive[bullet.row][bullet.column] = false
                score += (StarShooterWallpaper.rows - bullet.row) * 100
                let colors = [ArcadeTheme.pink, ArcadeTheme.cyan, ArcadeTheme.green, ArcadeTheme.yellow]
                explosions.append(Explosion(point: target, time: frame.time, color: colors[bullet.row]))
                return true
            }
            return bullet.y < -layout.pixel * 10
        }
        explosions.removeAll { frame.time - $0.time > 0.5 }
    }

    /// The lowest invader in the column nearest the ship.
    private func pickTarget(layout: StarShooterWallpaper.Layout, beat: Int) -> (column: Int, row: Int)? {
        var best: (column: Int, row: Int, distance: CGFloat)?
        for column in 0..<StarShooterWallpaper.columns {
            let targeted = Set(bullets.filter { $0.column == column }.map(\.row))
            guard let row = (0..<StarShooterWallpaper.rows).reversed().first(where: { alive[$0][column] && !targeted.contains($0) }) else { continue }
            let distance = abs(layout.invader(column: column, row: row, beat: beat, descent: 0).x - shipX) + CGFloat(hash01(column, beat)) * layout.spacingX * 2
            if best == nil || distance < best!.distance { best = (column, row, distance) }
        }
        guard let best else { return nil }
        targetColumn = best.column
        return (best.column, best.row)
    }
}
