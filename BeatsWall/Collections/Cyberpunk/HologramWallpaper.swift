//
//  HologramWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct HologramWallpaper: View {
    let context: WallpaperContext
    @State private var spin = PhaseClock()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            AudioTimeline(context: context) { frame in
                let glitch = 0.08 + 0.9 * pow(Double(frame.audio.beatPulse), 3) * Double(frame.audio.bass)
                Canvas { graphics, size in
                    draw(in: &graphics, size: size, frame: frame)
                }
                .layerEffect(ShaderLibrary.vhs(.float(frame.time), .float(glitch), .float2(size)), maxSampleOffset: CGSize(width: 40, height: 0))
                .colorEffect(ShaderLibrary.scanlines(.float(frame.time), .float(0.18), .float(3)))
            }
        }
    }

    private struct Point3 {
        var x: Double, y: Double, z: Double
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let yaw = spin.advance(to: frame.time, speed: 0.25 + 0.9 * Double(audio.level))
        let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        let radius = unit * 0.24 * (1 + 0.04 * CGFloat(audio.beatPulse))

        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0x0A1424), CyberTheme.black]),
            center: center, startRadius: 0, endRadius: max(size.width, size.height) * 0.6
        ))

        // Perspective floor grid.
        let horizon = size.height * 0.72
        var floor = Path()
        for index in 0..<14 {
            let z = Double(index) + 1 - (frame.time * 0.5).truncatingRemainder(dividingBy: 1)
            let y = horizon + (size.height - horizon) / CGFloat(z)
            floor.move(to: CGPoint(x: 0, y: y))
            floor.addLine(to: CGPoint(x: size.width, y: y))
        }
        for column in -12...12 {
            floor.move(to: CGPoint(x: size.width / 2, y: horizon))
            floor.addLine(to: CGPoint(x: size.width / 2 + CGFloat(column) * unit * 0.25, y: size.height))
        }
        var floorContext = graphics
        floorContext.clip(to: Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)))
        floorContext.stroke(floor, with: .color(CyberTheme.magenta.opacity(0.25)), lineWidth: max(1, unit * 0.0015))

        // Projector beam.
        let emitter = CGPoint(x: center.x, y: horizon + unit * 0.02)
        var beam = Path()
        beam.addLines([emitter + CGPoint(x: -unit * 0.03, y: 0), emitter + CGPoint(x: unit * 0.03, y: 0), center + CGPoint(x: radius * 1.1, y: radius * 0.3), center + CGPoint(x: -radius * 1.1, y: radius * 0.3)])
        beam.closeSubpath()
        var light = graphics
        light.blendMode = .plusLighter
        light.fill(beam, with: .linearGradient(
            Gradient(colors: [CyberTheme.cyan.opacity(0.3), CyberTheme.cyan.opacity(0)]),
            startPoint: emitter, endPoint: center
        ))
        light.fill(Path(ellipseIn: CGRect(x: emitter.x - unit * 0.08, y: emitter.y - unit * 0.015, width: unit * 0.16, height: unit * 0.03)), with: .color(CyberTheme.cyan.opacity(0.6)))

        // Wireframe globe: latitude and longitude lines, spinning in 3D.
        func project(_ p: Point3, scale: CGFloat) -> CGPoint {
            let cosY = cos(yaw), sinY = sin(yaw)
            let tilt = 0.35
            let x = p.x * cosY + p.z * sinY
            var z = -p.x * sinY + p.z * cosY
            let y = p.y * cos(tilt) - z * sin(tilt)
            z = p.y * sin(tilt) + z * cos(tilt)
            let perspective = 2.6 / (2.6 + z)
            return center + CGPoint(x: CGFloat(x * perspective), y: CGFloat(y * perspective)) * scale
        }
        var wire = Path()
        for latitude in stride(from: -60.0, through: 60.0, by: 30.0) {
            let lat = latitude * .pi / 180
            for step in 0...36 {
                let lon = Double(step) / 36 * 2 * .pi
                let point = project(Point3(x: cos(lat) * cos(lon), y: sin(lat), z: cos(lat) * sin(lon)), scale: radius)
                if step == 0 { wire.move(to: point) } else { wire.addLine(to: point) }
            }
        }
        for longitude in 0..<12 {
            let lon = Double(longitude) / 12 * .pi
            for step in 0...36 {
                let lat = Double(step) / 36 * 2 * .pi
                let point = project(Point3(x: cos(lat) * cos(lon), y: sin(lat), z: cos(lat) * sin(lon)), scale: radius)
                if step == 0 { wire.move(to: point) } else { wire.addLine(to: point) }
            }
        }
        SynthwaveTheme.neon(wire, in: graphics, color: CyberTheme.cyan, width: max(1, unit * 0.0018), brightness: 0.55 + 0.35 * Double(audio.mid))

        // An inner octahedron that counter-rotates and swells with the bass.
        let core = radius * CGFloat(0.35 + 0.2 * Double(audio.bass))
        let vertices = [Point3(x: 1, y: 0, z: 0), Point3(x: -1, y: 0, z: 0), Point3(x: 0, y: 1, z: 0), Point3(x: 0, y: -1, z: 0), Point3(x: 0, y: 0, z: 1), Point3(x: 0, y: 0, z: -1)]
        let rotated = vertices.map { v in Point3(x: v.x * cos(-yaw * 2) - v.z * sin(-yaw * 2), y: v.y, z: v.x * sin(-yaw * 2) + v.z * cos(-yaw * 2)) }
        var octahedron = Path()
        for a in 0..<6 {
            for b in (a + 1)..<6 where !(a / 2 == b / 2) {
                octahedron.move(to: project(rotated[a], scale: core))
                octahedron.addLine(to: project(rotated[b], scale: core))
            }
        }
        SynthwaveTheme.neon(octahedron, in: graphics, color: CyberTheme.magenta, width: max(1, unit * 0.003))

        // Orbiting data ring.
        var orbit = Path()
        for step in 0...60 {
            let angle = Double(step) / 60 * 2 * .pi
            let point = project(Point3(x: cos(angle) * 1.35, y: 0.05 * sin(angle * 6 + frame.time * 3), z: sin(angle) * 1.35), scale: radius)
            if step == 0 { orbit.move(to: point) } else { orbit.addLine(to: point) }
        }
        graphics.stroke(orbit, with: .color(CyberTheme.acid.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, unit * 0.002), dash: [unit * 0.01, unit * 0.006]))

        // Readouts.
        let font = Font.system(size: unit * 0.022, weight: .medium, design: .monospaced)
        let bars = Int((Double(audio.level) * 10).rounded())
        let lines = [
            "SYS.LINK   ONLINE",
            String(format: "TEMPO      %03d BPM", Int(audio.bpm.rounded())),
            "SIGNAL     " + String(repeating: "█", count: bars) + String(repeating: "░", count: 10 - bars),
            String(format: "BEAT       %05d", audio.beatCount % 100_000),
        ]
        for (index, line) in lines.enumerated() {
            let text = graphics.resolve(Text(line).font(font).foregroundStyle(CyberTheme.cyan.opacity(0.85)))
            graphics.draw(text, at: CGPoint(x: unit * 0.06, y: unit * 0.08 + CGFloat(index) * unit * 0.035), anchor: .topLeading)
        }
    }
}
