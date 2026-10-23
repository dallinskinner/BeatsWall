//
//  MazeChaseWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct MazeChaseWallpaper: View {
    let context: WallpaperContext

    private static let maze = [
        "###################",
        "#o.......#.......o#",
        "#.##.###.#.###.##.#",
        "#.................#",
        "#.##.#.#####.#.##.#",
        "#....#...#...#....#",
        "####.###.#.###.####",
        "#....#.......#....#",
        "#.##.#.#####.#.##.#",
        "#.................#",
        "#.##.###.#.###.##.#",
        "#o.......#.......o#",
        "###################",
    ]
    /// Tiles keyed as `row * 100 + column`.
    private static func tiles(_ kind: Character) -> Set<Int> {
        var set = Set<Int>()
        for (row, line) in maze.enumerated() {
            for (column, character) in line.enumerated() where character == kind { set.insert(row * 100 + column) }
        }
        return set
    }
    private static let walls = tiles("#")
    private static let pellets = tiles("o")
    /// A loop through the corridors, found by following the left-hand wall.
    private static let route: [(col: Int, row: Int)] = {
        let directions = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        func open(_ c: Int, _ r: Int) -> Bool { !walls.contains(r * 100 + c) }
        var position = (col: 1, row: 1)
        var heading = 0
        var result: [(col: Int, row: Int)] = []
        repeat {
            result.append(position)
            for turn in [3, 0, 1, 2] {
                let candidate = (heading + turn) % 4
                let next = (col: position.col + directions[candidate].0, row: position.row + directions[candidate].1)
                if open(next.col, next.row) {
                    heading = candidate
                    position = next
                    break
                }
            }
        } while !(position.col == 1 && position.row == 1) && result.count < 2000
        return result
    }()
    private static let firstVisit: [Int: Int] = {
        var visits: [Int: Int] = [:]
        for (index, tile) in route.enumerated() where visits[tile.row * 100 + tile.col] == nil {
            visits[tile.row * 100 + tile.col] = index
        }
        return visits
    }()
    private static let bugColors = [ArcadeTheme.red, ArcadeTheme.pink, ArcadeTheme.cyan, ArcadeTheme.orange]

    var body: some View {
        GeometryReader { geometry in
            let pixel = ArcadeTheme.pixel(for: geometry.size, across: 160)
            AudioTimeline(context: context) { frame in
                Canvas { graphics, size in
                    draw(in: &graphics, size: size, frame: frame)
                }
                .colorEffect(ArcadeTheme.crt(time: frame.time, pixel: pixel))
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let columns = Self.maze[0].count
        let rows = Self.maze.count
        let tile = (min(size.width / CGFloat(columns + 2), size.height / CGFloat(rows + 3))).rounded(.down)
        let origin = CGPoint(x: ((size.width - tile * CGFloat(columns)) / 2).rounded(), y: ((size.height - tile * CGFloat(rows)) / 2 + tile * 0.5).rounded())
        func center(_ col: Int, _ row: Int) -> CGPoint {
            CGPoint(x: origin.x + (CGFloat(col) + 0.5) * tile, y: origin.y + (CGFloat(row) + 0.5) * tile)
        }

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ArcadeTheme.black))

        // Walls: dark fill with a bright edge wherever a wall meets a corridor.
        var fill = Path()
        var edges = Path()
        let inset = tile * 0.18
        for (row, line) in Self.maze.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                let rect = CGRect(x: origin.x + CGFloat(column) * tile, y: origin.y + CGFloat(row) * tile, width: tile, height: tile)
                fill.addRect(rect)
                func isWall(_ c: Int, _ r: Int) -> Bool { r < 0 || r >= rows || c < 0 || c >= columns || Self.walls.contains(r * 100 + c) }
                if !isWall(column, row - 1) { edges.move(to: CGPoint(x: rect.minX, y: rect.minY + inset)); edges.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + inset)) }
                if !isWall(column, row + 1) { edges.move(to: CGPoint(x: rect.minX, y: rect.maxY - inset)); edges.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - inset)) }
                if !isWall(column - 1, row) { edges.move(to: CGPoint(x: rect.minX + inset, y: rect.minY)); edges.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY)) }
                if !isWall(column + 1, row) { edges.move(to: CGPoint(x: rect.maxX - inset, y: rect.minY)); edges.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY)) }
            }
        }
        graphics.fill(fill, with: .color(ArcadeTheme.mazeFill))
        graphics.stroke(edges, with: .color(ArcadeTheme.mazeBlue.mix(with: .white, by: 0.25 * Double(audio.beatPulse))), lineWidth: max(2, tile * 0.1))

        // Two tiles per beat around the loop; dots behind the hero are eaten until the lap resets.
        let route = Self.route
        let progress = audio.beatProgress(at: frame.time) * 2
        let step = Int(progress.rounded(.down))
        let fraction = CGFloat(progress - progress.rounded(.down))
        let lapIndex = ((step % route.count) + route.count) % route.count
        func position(at index: Int) -> (point: CGPoint, direction: CGPoint) {
            let a = route[((index % route.count) + route.count) % route.count]
            let b = route[(((index + 1) % route.count) + route.count) % route.count]
            let start = center(a.col, a.row)
            let end = center(b.col, b.row)
            return (start + (end - start) * fraction, CGPoint(x: CGFloat(b.col - a.col), y: CGFloat(b.row - a.row)))
        }

        var dots = Path()
        var pellets = Path()
        for (row, line) in Self.maze.enumerated() {
            for (column, character) in line.enumerated() where character == "." || character == "o" {
                if let visited = Self.firstVisit[row * 100 + column], visited <= lapIndex { continue }
                let c = center(column, row)
                if character == "." {
                    let r = (tile * 0.09).rounded(.up)
                    dots.addRect(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                } else {
                    let r = tile * CGFloat(0.22 + 0.12 * Double(audio.bass))
                    pellets.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                }
            }
        }
        graphics.fill(dots, with: .color(ArcadeTheme.dot))
        graphics.fill(pellets, with: .color(ArcadeTheme.dot.opacity(0.6 + 0.4 * Double(audio.beatPulse))))

        // Bugs chase along the same loop, turning blue after the hero eats a power pellet.
        var frightened = false
        for back in 0..<14 {
            let tileBehind = route[((step - back) % route.count + route.count) % route.count]
            if Self.pellets.contains(tileBehind.row * 100 + tileBehind.col) { frightened = true }
        }
        let bugPixel = (tile / 10).rounded(.down)
        for (index, offset) in [8, 13, 18, 23].enumerated() {
            let (point, _) = position(at: step - offset)
            let frames = index % 2 == 0 ? ArcadeTheme.bugA : ArcadeTheme.bugB
            let sprite = frames[audio.beatCount % 2]
            let color: Color = frightened
                ? (Int(frame.time * 6) % 2 == 0 ? ArcadeTheme.mazeBlue : ArcadeTheme.white)
                : Self.bugColors[index]
            ArcadeTheme.drawSprite(sprite, palette: ["#": color], origin: CGPoint(x: (point.x - bugPixel * 4).rounded(), y: (point.y - bugPixel * 4).rounded()), pixel: bugPixel, in: graphics)
        }

        // The hero: a green chomper, mouth snapping in tempo.
        let (hero, direction) = position(at: step)
        let chomp = abs(sin(.pi * progress)) * 0.85
        let facing = atan2(Double(direction.y), Double(direction.x))
        let radius = tile * 0.42
        var body = Path()
        body.move(to: hero)
        body.addArc(center: hero, radius: radius, startAngle: .radians(facing + chomp * 0.5), endAngle: .radians(facing - chomp * 0.5 + 2 * .pi), clockwise: false)
        body.closeSubpath()
        graphics.fill(body, with: .color(ArcadeTheme.green))
        let eye = hero + CGPoint(x: cos(facing - 1.2) * radius * 0.5, y: sin(facing - 1.2) * radius * 0.5)
        graphics.fill(Path(CGRect(x: eye.x - bugPixel, y: eye.y - bugPixel, width: bugPixel * 2, height: bugPixel * 2)), with: .color(ArcadeTheme.black))

        // Score.
        let font = Font.system(size: tile * 0.6, weight: .heavy, design: .monospaced)
        let score = graphics.resolve(Text(String(format: "SCORE %06d", (lapIndex * 10 + audio.beatCount * 50) % 1_000_000)).font(font).foregroundStyle(ArcadeTheme.white))
        graphics.draw(score, at: CGPoint(x: origin.x, y: origin.y - tile * 0.5), anchor: .bottomLeading)
        let high = graphics.resolve(Text("HI 999990").font(font).foregroundStyle(ArcadeTheme.red))
        graphics.draw(high, at: CGPoint(x: origin.x + tile * CGFloat(columns), y: origin.y - tile * 0.5), anchor: .bottomTrailing)
    }
}
