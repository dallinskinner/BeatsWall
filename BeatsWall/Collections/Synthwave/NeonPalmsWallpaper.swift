//
//  NeonPalmsWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct NeonPalmsWallpaper: View {
    let context: WallpaperContext
    @State private var water = PhaseClock()
    @State private var sway = PhaseClock()

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(ShaderLibrary.grain(.float(0.025)))
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let horizon = size.height * 0.64
        let center = size.width / 2
        let ripple = water.advance(to: frame.time, speed: 0.8 + 2.5 * Double(audio.mid))
        let breeze = sway.advance(to: frame.time, speed: 0.6 + 0.8 * Double(audio.mid))

        graphics.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x1B0638), Color(hex: 0x5B1A6E), SynthwaveTheme.magenta, SynthwaveTheme.orange, SynthwaveTheme.yellow]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
        ))
        SynthwaveTheme.drawStars(in: &graphics, size: size, maxY: horizon * 0.35, count: 50, twinkle: Double(audio.treble), time: frame.time)
        let sunRadius = unit * 0.3
        SynthwaveTheme.drawSun(in: &graphics, center: CGPoint(x: center, y: horizon - sunRadius * 0.35), radius: sunRadius, bass: Double(audio.bass), scroll: frame.time * 0.12)

        // Water with a rippling sun reflection.
        graphics.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x3A0E5A), SynthwaveTheme.night]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)
        ))
        let lines = 22
        for index in 0..<lines {
            let t = Double(index) / Double(lines)
            let y = horizon + (size.height - horizon) * CGFloat(pow(t, 1.35)) + unit * 0.004
            let wobble = 0.6 + 0.4 * sin(ripple * 2 + Double(index) * 1.3)
            let halfWidth = sunRadius * CGFloat((1 - t * 0.7) * wobble * (0.75 + 0.4 * Double(audio.mid)))
            let shift = CGFloat(sin(ripple + Double(index) * 0.7)) * unit * 0.01
            let color = SynthwaveTheme.yellow.mix(with: SynthwaveTheme.magenta, by: t * 1.4)
            graphics.fill(
                Path(roundedRect: CGRect(x: center - halfWidth + shift, y: y, width: halfWidth * 2, height: unit * (0.004 + 0.006 * t)), cornerRadius: unit * 0.003),
                with: .color(color.opacity(0.85 - 0.6 * t))
            )
        }
        var horizonLine = Path()
        horizonLine.addLines([CGPoint(x: 0, y: horizon), CGPoint(x: size.width, y: horizon)])
        SynthwaveTheme.neon(horizonLine, in: graphics, color: SynthwaveTheme.magenta, width: max(1, unit * 0.002))

        // Palms in silhouette.
        let palms: [(x: CGFloat, height: CGFloat, lean: CGFloat, scale: CGFloat)] = [
            (0.1, 0.78, 0.12, 1.0), (0.22, 0.6, 0.06, 0.75), (0.9, 0.82, -0.14, 1.05), (0.79, 0.55, -0.05, 0.7),
        ]
        for (index, palm) in palms.enumerated() {
            drawPalm(
                in: &graphics,
                base: CGPoint(x: size.width * palm.x, y: size.height + unit * 0.02),
                height: size.height * palm.height,
                lean: unit * palm.lean,
                scale: unit * palm.scale,
                sway: sin(breeze + Double(index) * 1.7) * (0.04 + 0.08 * Double(audio.mid))
            )
        }

        drawSign(in: &graphics, size: size, unit: unit, frame: frame)
    }

    private func drawPalm(in graphics: inout GraphicsContext, base: CGPoint, height: CGFloat, lean: CGFloat, scale: CGFloat, sway: Double) {
        let silhouette = SynthwaveTheme.night
        let top = CGPoint(x: base.x + lean, y: base.y - height)
        let control = CGPoint(x: base.x + lean * 0.1, y: base.y - height * 0.6)
        // Tapered trunk: walk the curve and offset each side.
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for step in 0...20 {
            let t = CGFloat(step) / 20
            let point = base * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + top * (t * t)
            let width = scale * (0.028 - 0.014 * t)
            left.append(point + CGPoint(x: -width, y: 0))
            right.append(point + CGPoint(x: width, y: 0))
        }
        var trunk = Path()
        trunk.addLines(left + right.reversed())
        trunk.closeSubpath()
        graphics.fill(trunk, with: .color(silhouette))

        let fronds = 8
        for index in 0..<fronds {
            let spread = Double(index) / Double(fronds - 1)
            let angle = -.pi * (0.06 + 0.88 * spread) + sway * (1 + spread)
            let length = scale * CGFloat(0.2 + 0.06 * sin(Double(index) * 2.1))
            let droop = scale * 0.09
            let tip = top + CGPoint(x: cos(angle) * length, y: sin(angle) * length * 0.55 + droop)
            let mid = top + CGPoint(x: cos(angle) * length * 0.55, y: sin(angle) * length * 0.55 - droop * 0.2)
            let normal = CGPoint(x: -sin(angle), y: cos(angle)) * (scale * 0.035)
            var frond = Path()
            frond.move(to: top)
            frond.addQuadCurve(to: tip, control: mid + normal)
            frond.addQuadCurve(to: top, control: mid - normal)
            frond.closeSubpath()
            graphics.fill(frond, with: .color(silhouette))
        }
        for offset: CGFloat in [-0.012, 0.012] {
            let r = scale * 0.016
            graphics.fill(Path(ellipseIn: CGRect(x: top.x + scale * offset - r, y: top.y + scale * 0.012, width: r * 2, height: r * 2)), with: .color(silhouette))
        }
    }

    private func drawSign(in graphics: inout GraphicsContext, size: CGSize, unit: CGFloat, frame: AudioFrame) {
        let audio = frame.audio
        // Mostly steady, brightening on the beat; some beats make the tube sputter.
        var brightness = 0.7 + 0.3 * Double(audio.beatPulse)
        if hash01(audio.beatCount, 3) > 0.7, audio.beatPulse > 0.45, sin(frame.time * 90) > 0 {
            brightness *= 0.25
        }
        let position = CGPoint(x: size.width / 2, y: size.height * 0.17)
        let font = Font.system(size: unit * 0.12, weight: .heavy, design: .rounded).italic()
        graphics.drawLayer { layer in
            layer.addFilter(.shadow(color: SynthwaveTheme.cyan.opacity(brightness), radius: unit * 0.03))
            layer.addFilter(.shadow(color: SynthwaveTheme.cyan.opacity(brightness), radius: unit * 0.008))
            let text = layer.resolve(Text("Beats").font(font).foregroundStyle(Color.white.mix(with: SynthwaveTheme.cyan, by: 0.4).opacity(0.35 + 0.65 * brightness)))
            layer.draw(text, at: position)
        }
        var underline = Path()
        underline.addLines([position + CGPoint(x: -unit * 0.17, y: unit * 0.08), position + CGPoint(x: unit * 0.17, y: unit * 0.08)])
        SynthwaveTheme.neon(underline, in: graphics, color: SynthwaveTheme.magenta, width: max(1, unit * 0.004), brightness: brightness)
    }
}
