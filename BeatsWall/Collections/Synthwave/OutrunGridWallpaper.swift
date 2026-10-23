//
//  OutrunGridWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct OutrunGridWallpaper: View {
    let context: WallpaperContext
    @State private var road = PhaseClock()
    @State private var sunScroll = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.58
        let center = size.width / 2
        let scroll = road.advance(to: frame.time, speed: 0.6 + 1.6 * SynthwaveTheme.tempo(audio) + 0.8 * Double(audio.level))
        let sunPhase = sunScroll.advance(to: frame.time, speed: 0.15)
        let pulse = Double(audio.beatPulse)

        graphics.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)), with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.deepNight, SynthwaveTheme.dusk, SynthwaveTheme.purple, SynthwaveTheme.magenta]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        SynthwaveTheme.drawStars(in: &graphics, size: size, maxY: horizon * 0.6, count: 90, twinkle: Double(audio.treble), time: frame.time)
        SynthwaveTheme.drawSun(in: &graphics, center: CGPoint(x: center, y: horizon - unit * 0.07), radius: unit * 0.26, bass: Double(audio.bass), scroll: sunPhase)

        // Wireframe mountains: peaks rise with the spectrum, lowest bins on the outside.
        let points = 48
        var ridge: [CGPoint] = []
        for index in 0...points {
            let x = size.width * CGFloat(index) / CGFloat(points)
            let fromCenter = abs(Double(index) / Double(points) - 0.5) * 2
            let bin = min(Int((1 - fromCenter) * 26), AudioFeatures.binCount - 1)
            let jagged = index % 2 == 0 ? 1.0 : 0.45
            let gap = smoothstep(0.3, 0.55, fromCenter)
            let height = unit * CGFloat((0.03 + 0.1 * hash01(index, 7) + 0.14 * Double(audio.spectrum[bin])) * jagged * gap)
            ridge.append(CGPoint(x: x, y: horizon - height))
        }
        var mountains = Path()
        mountains.move(to: CGPoint(x: 0, y: horizon))
        ridge.forEach { mountains.addLine(to: $0) }
        mountains.addLine(to: CGPoint(x: size.width, y: horizon))
        mountains.closeSubpath()
        graphics.fill(mountains, with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.dusk, SynthwaveTheme.night]),
            startPoint: CGPoint(x: 0, y: horizon - unit * 0.25), endPoint: CGPoint(x: 0, y: horizon)
        ))
        var wires = Path()
        for point in ridge where point.y < horizon - 1 {
            wires.move(to: point)
            wires.addLine(to: CGPoint(x: point.x + (center - point.x) * 0.15, y: horizon))
        }
        graphics.stroke(wires, with: .color(SynthwaveTheme.cyan.opacity(0.25)), lineWidth: max(1, unit * 0.0015))
        var ridgeLine = Path()
        ridgeLine.addLines(ridge)
        SynthwaveTheme.neon(ridgeLine, in: graphics, color: SynthwaveTheme.cyan, width: max(1, unit * 0.002))

        // Floor and grid.
        graphics.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)), with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.night, SynthwaveTheme.deepNight]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
        ))
        let depth = size.height - horizon
        var grid = Path()
        let offset = scroll - scroll.rounded(.down)
        for index in 0..<40 {
            let z = Double(index) + 1 - offset
            let y = horizon + depth / CGFloat(z)
            guard y <= size.height + 2 else { continue }
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        let spacing = unit * 0.16
        let columns = Int(size.width / spacing) + 4
        for column in -columns...columns {
            grid.move(to: CGPoint(x: center, y: horizon))
            grid.addLine(to: CGPoint(x: center + CGFloat(column) * spacing * 1.6, y: size.height))
        }
        var floorContext = graphics
        floorContext.clip(to: Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)))
        SynthwaveTheme.neon(grid, in: floorContext, color: SynthwaveTheme.magenta, width: max(1, unit * 0.0022), brightness: 0.6 + 0.4 * pulse)
        // Haze over the far end of the grid.
        floorContext.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: depth * 0.35)), with: .linearGradient(
            Gradient(colors: [SynthwaveTheme.night, SynthwaveTheme.night.opacity(0)]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: horizon + depth * 0.35)
        ))

        var horizonLine = Path()
        horizonLine.addLines([CGPoint(x: 0, y: horizon), CGPoint(x: size.width, y: horizon)])
        SynthwaveTheme.neon(horizonLine, in: graphics, color: SynthwaveTheme.magenta, width: max(1, unit * 0.003), brightness: 0.8 + 0.2 * pulse)
    }
}
