//
//  MidnightTrainWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct MidnightTrainWallpaper: View {
    let context: WallpaperContext
    @State private var schedule = TrainSchedule()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                schedule.step(frame: frame)
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(TokyoTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let track = size.height * 0.56
        let street = size.height * 0.82

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [TokyoTheme.night, Color(hex: 0x24204A), Color(hex: 0x6A3D6E)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: street)
        ))
        // City glow on the low clouds.
        graphics.fill(Path(CGRect(x: 0, y: size.height * 0.3, width: size.width, height: size.height * 0.4)), with: .linearGradient(
            Gradient(colors: [TokyoTheme.pink.opacity(0), TokyoTheme.pink.opacity(0.12 + 0.1 * Double(audio.bass)), TokyoTheme.pink.opacity(0)]),
            startPoint: CGPoint(x: 0, y: size.height * 0.3), endPoint: CGPoint(x: 0, y: size.height * 0.7)
        ))
        TokyoTheme.drawSkyline(in: &graphics, size: size, base: street, height: size.height * 0.55, seed: 20, color: Color(hex: 0x1B1D3A), windowColor: TokyoTheme.warm.opacity(0.4), spectrum: nil)
        TokyoTheme.drawSkyline(in: &graphics, size: size, base: street, height: size.height * 0.38, seed: 60, color: TokyoTheme.building, windowColor: TokyoTheme.cyan.opacity(0.75), spectrum: audio.spectrum)

        // Elevated track and pillars.
        let deck = CGRect(x: 0, y: track, width: size.width, height: unit * 0.035)
        var structure = Path(deck)
        var x: CGFloat = unit * 0.1
        while x < size.width {
            structure.addRect(CGRect(x: x, y: deck.maxY, width: unit * 0.03, height: street - deck.maxY))
            structure.addLines([CGPoint(x: x - unit * 0.05, y: deck.maxY), CGPoint(x: x + unit * 0.08, y: deck.maxY), CGPoint(x: x + unit * 0.015, y: deck.maxY + unit * 0.05)])
            structure.closeSubpath()
            x += unit * 0.42
        }
        // Overhead wire poles.
        var poles = Path()
        x = unit * 0.25
        while x < size.width {
            poles.addRect(CGRect(x: x, y: track - unit * 0.12, width: unit * 0.006, height: unit * 0.12))
            x += unit * 0.42
        }
        poles.addRect(CGRect(x: 0, y: track - unit * 0.1, width: size.width, height: max(1, unit * 0.0015)))

        drawTrain(in: &graphics, size: size, unit: unit, track: track, frame: frame)
        graphics.fill(structure, with: .color(Color(hex: 0x080A16)))
        graphics.fill(poles, with: .color(Color(hex: 0x080A16)))

        // Street level: shopfronts and passing car lights.
        graphics.fill(Path(CGRect(x: 0, y: street, width: size.width, height: size.height - street)), with: .color(TokyoTheme.asphalt))
        var shops = Path()
        var glow = graphics
        glow.blendMode = .plusLighter
        for index in 0..<12 {
            let rect = CGRect(x: size.width * CGFloat(index) / 12 + unit * 0.01, y: street - unit * 0.05, width: size.width / 12 - unit * 0.02, height: unit * 0.04)
            shops.addRect(rect)
            let color = TokyoTheme.neonColors[index % TokyoTheme.neonColors.count]
            glow.fill(Path(rect), with: .color(color.opacity(0.2 + 0.4 * Double(audio.spectrum[(index * 3) % AudioFeatures.binCount]))))
        }
        var lights = Path()
        for index in 0..<10 {
            let speed = (0.15 + 0.2 * hash01(index, 2)) * (index % 2 == 0 ? 1 : -1)
            let raw = (hash01(index, 1) + frame.time * speed).truncatingRemainder(dividingBy: 1)
            let lx = CGFloat(raw < 0 ? raw + 1 : raw) * (size.width + unit * 0.2) - unit * 0.1
            let ly = street + unit * (index % 2 == 0 ? 0.05 : 0.09)
            lights.addRoundedRect(in: CGRect(x: lx, y: ly, width: unit * 0.06, height: unit * 0.006), cornerSize: CGSize(width: unit * 0.003, height: unit * 0.003))
        }
        glow.fill(lights, with: .color(Color(hex: 0xFFE6B0).opacity(0.6)))
        TokyoTheme.drawRain(in: &graphics, size: size, time: frame.time, density: 0.3 + 0.4 * Double(audio.level))
    }

    private func drawTrain(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, track: CGFloat, frame: AudioFrame) {
        guard let progress = schedule.progress(at: frame.time) else { return }
        let carLength = unit * 0.32
        let cars = 6
        let trainLength = carLength * CGFloat(cars)
        let head = -trainLength + CGFloat(progress) * (size.width + trainLength * 1.1)
        let height = unit * 0.07
        let top = track - height
        var bodies = Path()
        var windows = Path()
        for car in 0..<cars {
            let left = head + CGFloat(car) * carLength
            bodies.addRoundedRect(in: CGRect(x: left + unit * 0.004, y: top, width: carLength - unit * 0.008, height: height), cornerSize: CGSize(width: unit * 0.008, height: unit * 0.008))
            var wx = left + unit * 0.02
            while wx < left + carLength - unit * 0.03 {
                windows.addRect(CGRect(x: wx, y: top + height * 0.2, width: unit * 0.03, height: height * 0.35))
                wx += unit * 0.04
            }
        }
        graphics.fill(bodies, with: .color(Color(hex: 0xC9CED8)))
        graphics.fill(Path(CGRect(x: head, y: top + height * 0.68, width: trainLength, height: height * 0.1)), with: .color(TokyoTheme.cyan.opacity(0.9)))
        let treble = Double(frame.audio.treble)
        graphics.fill(windows, with: .color(TokyoTheme.warm.opacity(0.75 + 0.25 * treble)))
        var glow = graphics
        glow.blendMode = .plusLighter
        glow.addFilter(.blur(radius: unit * 0.01))
        glow.fill(windows, with: .color(TokyoTheme.warm.opacity(0.35)))
        let lamp = CGPoint(x: head + trainLength, y: top + height * 0.6)
        glow.fill(Path(ellipseIn: CGRect(x: lamp.x - unit * 0.01, y: lamp.y - unit * 0.01, width: unit * 0.02, height: unit * 0.02)), with: .color(.white))
    }
}

/// Trains roll through on the downbeat of every 16 beats, or every 15 seconds when it's quiet.
private final class TrainSchedule {
    private var beatEdge = BeatEdge()
    private var departure: Double?
    private static let crossing = 5.0

    func progress(at time: Double) -> Double? {
        guard let departure else { return nil }
        let t = (time - departure) / Self.crossing
        return t >= 0 && t <= 1 ? t : nil
    }

    func step(frame: AudioFrame) {
        let busy = progress(at: frame.time) != nil
        if beatEdge.isNewBeat(frame.audio), frame.audio.beatCount % 16 == 0, !busy {
            departure = frame.time
        } else if !busy, frame.time - (departure ?? -100) > 15 {
            departure = frame.time
        }
    }
}
