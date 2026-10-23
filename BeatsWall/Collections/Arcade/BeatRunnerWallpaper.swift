//
//  BeatRunnerWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct BeatRunnerWallpaper: View {
    let context: WallpaperContext
    @State private var run = RunnerScene()

    private static let robot = [
        [
            "..WWWWWW..", ".WWWWWWWW.", ".WCCCCCCW.", ".WCKCCKCW.", ".WWWWWWWW.", "..OOOOOO..",
            ".OOOOOOOO.", "WOOOOOOOOW", "..OOOOOO..", "..OO..OO..", ".OO....OO.", ".KK....KK.",
        ],
        [
            "..WWWWWW..", ".WWWWWWWW.", ".WCCCCCCW.", ".WCKCCKCW.", ".WWWWWWWW.", "..OOOOOO..",
            "WOOOOOOOOW", ".OOOOOOOO.", "..OOOOOO..", "...OOOO...", "...OO.OO..", "...KK.KK..",
        ],
    ]
    private static let robotPalette: [Character: Color] = ["W": ArcadeTheme.white, "C": ArcadeTheme.cyan, "K": ArcadeTheme.black, "O": ArcadeTheme.orange]
    private static let cloud = ["...####...", ".########.", "##########", ".########."]
    private static let pipeGreen = Color(hex: 0x3CC14A)
    private static let dirt = Color(hex: 0xC8742C)

    var body: some View {
        GeometryReader { geometry in
            let pixel = ArcadeTheme.pixel(for: geometry.size, across: 150)
            AudioTimeline(context: context) { frame in
                Canvas { graphics, size in
                    let tile = pixel * 8
                    run.step(frame: frame, tile: tile, heroCenter: ArcadeTheme.snap(size.width * 0.28, to: pixel) + pixel * 15)
                    draw(in: &graphics, size: size, pixel: pixel, tile: tile, frame: frame)
                }
                .colorEffect(ArcadeTheme.crt(time: frame.time, pixel: pixel))
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, pixel: CGFloat, tile: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        let groundY = ArcadeTheme.snap(size.height * 0.78, to: tile)
        let distance = CGFloat(run.distance)
        let heroX = ArcadeTheme.snap(size.width * 0.28, to: pixel)

        // Banded sky.
        let bands = [Color(hex: 0x4FB3FF), Color(hex: 0x6EC6FF), Color(hex: 0x8ED4FF), Color(hex: 0xB5E8FF)]
        for (index, color) in bands.enumerated() {
            let top = groundY * CGFloat(index) / CGFloat(bands.count)
            graphics.fill(Path(CGRect(x: 0, y: top, width: size.width, height: groundY / CGFloat(bands.count) + 1)), with: .color(color))
        }
        for index in 0..<5 {
            let span = size.width + tile * 12
            let raw = CGFloat(hash01(index, 1)) * span - distance * 0.1
            let x = raw - (raw / span).rounded(.down) * span - tile * 6
            ArcadeTheme.drawSprite(Self.cloud, palette: ["#": ArcadeTheme.white], origin: CGPoint(x: ArcadeTheme.snap(x, to: pixel), y: ArcadeTheme.snap(size.height * CGFloat(0.08 + 0.25 * hash01(index, 2)), to: pixel)), pixel: pixel * 3, in: graphics)
        }

        // Stepped pixel hills: far and near layers.
        for (layer, (speed, color, height)) in [(0.2, Color(hex: 0x4CAF7A), 0.22), (0.45, Color(hex: 0x2E8B57), 0.12)].enumerated() {
            var hills = Path()
            let step = pixel * 4
            var x: CGFloat = 0
            while x < size.width {
                let world = Double(x + distance * CGFloat(speed)) / Double(tile * 6)
                let h = size.height * CGFloat(height) * CGFloat(0.5 + 0.35 * sin(world + Double(layer) * 2) + 0.15 * sin(world * 2.7))
                hills.addRect(CGRect(x: x, y: ArcadeTheme.snap(groundY - h, to: step), width: step, height: h + step))
                x += step
            }
            graphics.fill(hills, with: .color(color))
        }

        // Ground with brick texture, skipping pits.
        var ground = Path()
        var grass = Path()
        var bricks = Path()
        let firstTile = Int((distance / tile).rounded(.down))
        for index in firstTile...(firstTile + Int(size.width / tile) + 2) {
            let x = CGFloat(index) * tile - distance
            if run.isPit(tileIndex: index) { continue }
            ground.addRect(CGRect(x: x, y: groundY, width: tile, height: size.height - groundY))
            grass.addRect(CGRect(x: x, y: groundY, width: tile, height: pixel * 2))
            var y = groundY + pixel * 2
            var row = 0
            while y < size.height {
                bricks.addRect(CGRect(x: x, y: y, width: tile, height: pixel * 0.6))
                bricks.addRect(CGRect(x: x + (row % 2 == 0 ? 0 : tile / 2), y: y, width: pixel * 0.6, height: tile / 2))
                y += tile / 2
                row += 1
            }
        }
        graphics.fill(ground, with: .color(Self.dirt))
        graphics.fill(bricks, with: .color(Color(hex: 0x8A4A1C)))
        graphics.fill(grass, with: .color(Color(hex: 0x5BD15B)))

        // Pipes.
        for obstacle in run.obstacles where obstacle.kind == .pipe {
            let x = CGFloat(obstacle.tile) * tile - distance
            let height = tile * CGFloat(obstacle.height)
            let body = CGRect(x: x + pixel, y: groundY - height, width: tile * 2 - pixel * 2, height: height)
            let lip = CGRect(x: x, y: groundY - height, width: tile * 2, height: tile * 0.6)
            graphics.fill(Path(body), with: .color(Self.pipeGreen))
            graphics.fill(Path(lip), with: .color(Self.pipeGreen))
            graphics.fill(Path(CGRect(x: body.minX + pixel * 2, y: body.minY, width: pixel * 2, height: body.height)), with: .color(Color(hex: 0x9BF59E)))
            graphics.stroke(Path(body), with: .color(ArcadeTheme.black), lineWidth: pixel)
            graphics.stroke(Path(lip), with: .color(ArcadeTheme.black), lineWidth: pixel)
        }

        // Coins arc over each obstacle and sparkle with the hi-hats.
        for obstacle in run.obstacles {
            for coin in 0..<3 {
                let x = CGFloat(obstacle.tile) * tile - distance + tile * CGFloat(coin)
                let y = groundY - tile * CGFloat(obstacle.height + 2) - tile * (coin == 1 ? 0.8 : 0)
                let spin = abs(cos(frame.time * 5 + Double(coin + obstacle.tile)))
                let width = max(pixel, ArcadeTheme.snap(tile * 0.5 * CGFloat(spin), to: pixel))
                let rect = CGRect(x: x + tile / 2 - width / 2, y: y, width: width, height: tile * 0.7)
                graphics.fill(Path(rect), with: .color(ArcadeTheme.yellow))
                graphics.stroke(Path(rect), with: .color(Color(hex: 0xB8860B)), lineWidth: pixel)
                if audio.treble > 0.5, hash01(coin + obstacle.tile, Int(frame.time * 8)) > 0.6 {
                    var sparkle = Path()
                    sparkle.addRect(CGRect(x: rect.maxX, y: rect.minY - pixel * 2, width: pixel, height: pixel * 3))
                    sparkle.addRect(CGRect(x: rect.maxX - pixel, y: rect.minY - pixel, width: pixel * 3, height: pixel))
                    graphics.fill(sparkle, with: .color(.white))
                }
            }
        }

        // The runner: two-frame run cycle, twice per beat; jumps on the beat.
        let height = ArcadeTheme.snap(CGFloat(run.jumpHeight(at: frame.time)) * tile, to: pixel)
        let runFrame = height > 0 ? 1 : Int(audio.beatProgress(at: frame.time) * 2) % 2
        ArcadeTheme.drawSprite(Self.robot[runFrame], palette: Self.robotPalette, origin: CGPoint(x: heroX, y: groundY - pixel * 3 * 12 - height), pixel: pixel * 3, in: graphics)

        let font = Font.system(size: pixel * 6, weight: .heavy, design: .monospaced)
        let hud = graphics.resolve(Text(String(format: "BEAT %04d   COINS x%02d", audio.beatCount % 10_000, run.coins % 100)).font(font).foregroundStyle(.white))
        graphics.draw(hud, at: CGPoint(x: pixel * 8, y: pixel * 6), anchor: .topLeading)
    }
}

/// Scrolling, beat-timed jumps and obstacles spawned to arrive at the top of a jump.
private final class RunnerScene {
    enum Kind { case pipe, pit }

    struct Obstacle {
        var tile: Int
        var kind: Kind
        var height: Int
    }

    private let clock = PhaseClock()
    private var beatEdge = BeatEdge()
    private var jumpStart: Double?
    private var jumpDuration = 0.5
    private(set) var obstacles: [Obstacle] = []
    private(set) var coins = 0

    var distance: Double { clock.phase }

    func isPit(tileIndex: Int) -> Bool {
        obstacles.contains { $0.kind == .pit && tileIndex >= $0.tile && tileIndex < $0.tile + 2 }
    }

    /// Jump height in tiles.
    func jumpHeight(at time: Double) -> Double {
        guard let jumpStart else { return 0 }
        let t = (time - jumpStart) / jumpDuration
        return t >= 0 && t <= 1 ? 3.5 * sin(.pi * t) : 0
    }

    func step(frame: AudioFrame, tile: CGFloat, heroCenter: CGFloat) {
        let audio = frame.audio
        let tempo = audio.bpm > 0 ? min(max((Double(audio.bpm) - 70) / 90, 0), 1) : 0.5
        let speed = Double(tile) * (4 + 4 * tempo)
        clock.advance(to: frame.time, speed: speed)

        if beatEdge.isNewBeat(audio), audio.beatCount % 2 == 0 {
            jumpStart = frame.time
            jumpDuration = min(0.6, audio.beatLength * 1.2)
            // Something to jump over at the apex of the jump two beats from now.
            let lead = audio.beatLength * 2 + jumpDuration / 2
            // A tile's screen x is `tile * size - distance`, so it reaches the hero when
            // `tile * size == distance + heroCenter`. Obstacles are two tiles wide.
            let arrival = distance + Double(heroCenter) + speed * lead
            if hash01(audio.beatCount, 5) < 0.75 {
                let kind: Kind = hash01(audio.beatCount, 6) < 0.6 ? .pipe : .pit
                obstacles.append(Obstacle(tile: Int(arrival / Double(tile)) - 1, kind: kind, height: kind == .pipe ? 1 + Int(hash01(audio.beatCount, 7) * 2) : 0))
            }
            coins += 1
        }
        obstacles.removeAll { Double($0.tile) * Double(tile) < distance - Double(tile) * 40 }
    }
}
