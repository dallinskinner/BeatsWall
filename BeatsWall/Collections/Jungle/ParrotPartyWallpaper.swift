//
//  ParrotPartyWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct ParrotPartyWallpaper: View {
    let context: WallpaperContext
    @State private var breeze = PhaseClock()

    private struct Plumage {
        var body: Color
        var wing: Color
        var accent: Color
        var face: Color
    }

    private static let parrots: [(x: CGFloat, plumage: Plumage)] = [
        (0.2, Plumage(body: JungleTheme.red, wing: JungleTheme.blue, accent: JungleTheme.yellow, face: .white)),
        (0.4, Plumage(body: JungleTheme.blue, wing: Color(hex: 0x155A9E), accent: JungleTheme.yellow, face: .white)),
        (0.6, Plumage(body: Color(hex: 0x3BB273), wing: Color(hex: 0x1F7A4D), accent: JungleTheme.red, face: Color(hex: 0xE8F5C8))),
        (0.8, Plumage(body: JungleTheme.yellow, wing: Color(hex: 0x3BB273), accent: JungleTheme.blue, face: .white)),
    ]

    var body: some View {
        AudioTimeline(context: context) { frame in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, frame: frame)
            }
        }
        .colorEffect(JungleTheme.grain())
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, frame: AudioFrame) {
        let audio = frame.audio
        let unit = min(size.width, size.height)
        let wind = breeze.advance(to: frame.time, speed: 0.5 + Double(audio.mid))

        // Soft-focus jungle behind.
        graphics.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x9FD48A), JungleTheme.leaf, JungleTheme.mid]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.02))
            for index in 0..<14 {
                let base = CGPoint(x: CGFloat(hash01(index, 1)) * size.width, y: index % 2 == 0 ? -unit * 0.05 : size.height + unit * 0.05)
                let angle = (index % 2 == 0 ? Double.pi / 2 : -Double.pi / 2) + (hash01(index, 2) - 0.5) + sin(wind + Double(index)) * 0.05
                let (leaf, _) = JungleTheme.monstera(base: base, angle: angle, length: unit * CGFloat(0.3 + 0.2 * hash01(index, 3)))
                layer.fill(leaf, with: .color(index % 3 == 0 ? JungleTheme.shade.opacity(0.7) : JungleTheme.mid.opacity(0.8)))
            }
        }

        // The branch.
        let branchY = size.height * 0.68
        var branch = Path()
        branch.move(to: CGPoint(x: -unit * 0.05, y: branchY + unit * 0.04))
        branch.addCurve(to: CGPoint(x: size.width + unit * 0.05, y: branchY - unit * 0.02), control1: CGPoint(x: size.width * 0.3, y: branchY - unit * 0.03), control2: CGPoint(x: size.width * 0.7, y: branchY + unit * 0.05))
        graphics.stroke(branch, with: .color(JungleTheme.bark), style: StrokeStyle(lineWidth: unit * 0.035, lineCap: .round))
        graphics.stroke(branch, with: .color(Color(hex: 0x7A5233)), style: StrokeStyle(lineWidth: unit * 0.01, lineCap: .round))

        let beat = audio.beatProgress(at: frame.time)
        for (index, parrot) in Self.parrots.enumerated() {
            let x = size.width * parrot.x
            let t = Double(parrot.x)
            // Where the branch is under this parrot.
            let perch = branchY + unit * CGFloat(0.04 * pow(1 - t, 3) - 0.03 * 3 * pow(1 - t, 2) * t + 0.05 * 3 * (1 - t) * t * t - 0.02 * pow(t, 3))
            // Alternate parrots bob on and off the beat.
            let local = beat + (index % 2 == 0 ? 0 : 0.5)
            let fraction = local - local.rounded(.down)
            let bob = exp(-fraction * 6)
            let flare = audio.bass > 0.65 ? Double(audio.beatPulse) : 0
            drawParrot(in: graphics, feet: CGPoint(x: x, y: perch - unit * 0.015), scale: unit * 0.17, bob: bob, flare: flare, facing: index < 2 ? 1 : -1, plumage: parrot.plumage)
        }
    }

    private func drawParrot(in graphics: GraphicsContext, feet: CGPoint, scale: CGFloat, bob: Double, flare: Double, facing: CGFloat, plumage: Plumage) {
        var g = graphics
        g.translateBy(x: feet.x, y: feet.y)
        g.scaleBy(x: scale * facing, y: scale)
        let dip = CGFloat(bob) * 0.12

        // Long tail hanging down behind the branch.
        var tail = Path()
        tail.addLines([CGPoint(x: -0.12, y: -0.15), CGPoint(x: -0.35, y: 0.9), CGPoint(x: -0.22, y: 0.95), CGPoint(x: 0.05, y: -0.1)])
        tail.closeSubpath()
        g.fill(tail, with: .color(plumage.wing))
        var tailTip = Path()
        tailTip.addLines([CGPoint(x: -0.3, y: 0.7), CGPoint(x: -0.35, y: 0.9), CGPoint(x: -0.22, y: 0.95), CGPoint(x: -0.17, y: 0.72)])
        tailTip.closeSubpath()
        g.fill(tailTip, with: .color(plumage.accent))

        // Body, leaning forward a little more on each bob.
        var body = g
        body.rotate(by: .radians(0.25 + Double(dip)))
        body.fill(Path(ellipseIn: CGRect(x: -0.22, y: -0.75, width: 0.44, height: 0.8)), with: .color(plumage.body))
        // Wing: folded, or flared out on big hits.
        var wing = body
        wing.translateBy(x: -0.05, y: -0.5)
        wing.rotate(by: .radians(-1.6 * flare))
        var wingShape = Path()
        wingShape.move(to: .zero)
        wingShape.addQuadCurve(to: CGPoint(x: -0.12, y: 0.62), control: CGPoint(x: 0.2, y: 0.3))
        wingShape.addQuadCurve(to: .zero, control: CGPoint(x: -0.25, y: 0.2))
        wing.fill(wingShape, with: .color(plumage.wing))
        var feathers = Path()
        for step in 1...3 {
            feathers.move(to: CGPoint(x: -0.02 * CGFloat(step), y: 0.15 * CGFloat(step)))
            feathers.addLine(to: CGPoint(x: -0.1 - 0.02 * CGFloat(step), y: 0.2 + 0.15 * CGFloat(step)))
        }
        wing.stroke(feathers, with: .color(.black.opacity(0.2)), lineWidth: 0.015)
        // Wing accent stripe.
        wing.fill(Path(ellipseIn: CGRect(x: -0.04, y: 0.05, width: 0.12, height: 0.18)), with: .color(plumage.accent))

        // Head bobs forward and down on the beat.
        let head = CGPoint(x: 0.12 + dip * 0.8, y: -0.82 + dip)
        g.fill(Path(ellipseIn: CGRect(x: head.x - 0.19, y: head.y - 0.19, width: 0.38, height: 0.38)), with: .color(plumage.body))
        g.fill(Path(ellipseIn: CGRect(x: head.x - 0.02, y: head.y - 0.1, width: 0.2, height: 0.2)), with: .color(plumage.face))
        g.fill(Path(ellipseIn: CGRect(x: head.x + 0.05, y: head.y - 0.06, width: 0.07, height: 0.07)), with: .color(.black))
        g.fill(Path(ellipseIn: CGRect(x: head.x + 0.07, y: head.y - 0.05, width: 0.02, height: 0.02)), with: .color(.white))
        var beak = Path()
        beak.move(to: head + CGPoint(x: 0.14, y: -0.06))
        beak.addQuadCurve(to: head + CGPoint(x: 0.24, y: 0.12), control: head + CGPoint(x: 0.3, y: -0.06))
        beak.addQuadCurve(to: head + CGPoint(x: 0.14, y: 0.06), control: head + CGPoint(x: 0.18, y: 0.06))
        beak.closeSubpath()
        g.fill(beak, with: .color(Color(hex: 0x2B2B2B)))

        // Feet gripping the branch.
        var toes = Path()
        for dx: CGFloat in [-0.05, 0.08] {
            toes.addEllipse(in: CGRect(x: dx - 0.05, y: -0.04, width: 0.1, height: 0.07))
        }
        g.fill(toes, with: .color(Color(hex: 0x6B6B6B)))
    }
}
