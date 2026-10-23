//
//  SkaterFigure.swift
//  BeatsWall
//

import SwiftUI

struct SkaterPalette {
    var shirt = SkateTheme.orange
    var cap = SkateTheme.yellow
    var deckBottom = SkateTheme.pink
    var pants = SkateTheme.denim
    var skin = SkateTheme.skin
    var shoes = SkateTheme.offWhite
    var ink = SkateTheme.ink
}

struct SkaterPose {
    /// 0 standing tall, 1 deep crouch.
    var crouch: Double = 0.15
    /// Radians; positive leans toward the direction of travel.
    var lean: Double = 0
    /// 0 arms hanging, 1 arms out for balance.
    var armsOut: Double = 0.3
    /// -1...1 swings both arms back and forth.
    var armSwing: Double = 0
    /// Gap between feet and board, in units (board dropping away during flip tricks).
    var boardDrop: Double = 0
    /// Radians; positive lifts the nose (ollie pop).
    var boardTilt: Double = 0
    /// Kickflip progress 0...1: the board rolls around its long axis.
    var flip: Double = 0
    /// Shuvit progress 0...1: the board spins flat underneath.
    var spin: Double = 0
    /// 0...1: front hand reaches down to grab the nose.
    var grab: Double = 0
}

enum SkateTrick {
    case ollie, kickflip, shuvit, grab

    /// Strong beats get a flip trick or grab, others a plain ollie. Deterministic per beat.
    static func forBeat(_ beat: Int, strong: Bool) -> SkateTrick {
        guard strong else { return .ollie }
        let options: [SkateTrick] = [.kickflip, .shuvit, .grab, .kickflip, .shuvit]
        return options[min(Int(hash01(beat, 41) * Double(options.count)), options.count - 1)]
    }

    /// Pose while airborne; `progress` is 0 at takeoff and 1 at landing.
    func pose(progress: Double, base: SkaterPose = SkaterPose()) -> SkaterPose {
        var pose = base
        let arc = sin(.pi * progress)
        pose.crouch = base.crouch + (0.7 - base.crouch) * arc
        pose.armsOut = max(base.armsOut, 0.35 + 0.55 * arc)
        // Pop: tail snaps down so the nose lifts, then the board levels out.
        pose.boardTilt = 0.4 * sin(.pi * min(progress * 2.2, 1)) * (1 - progress)
        switch self {
        case .ollie:
            break
        case .kickflip:
            pose.flip = smoothstep(0.12, 0.72, progress)
            pose.boardDrop = 1.1 * arc
        case .shuvit:
            pose.spin = smoothstep(0.1, 0.78, progress)
            pose.boardDrop = 0.7 * arc
        case .grab:
            pose.grab = smoothstep(0.08, 0.38, progress) * (1 - smoothstep(0.62, 0.9, progress))
            pose.crouch = base.crouch + (0.95 - base.crouch) * arc
        }
        return pose
    }
}

/// A flat-illustration skater rig. Coordinates are in "units" (standing height ≈ 10 units),
/// with the origin at the center of the deck's top surface; wheels touch down at y ≈ 1.45.
enum SkaterFigure {
    /// Distance from the deck origin to the ground under the wheels, in units.
    static let wheelBase: CGFloat = 1.45

    /// - Parameters:
    ///   - rotation: tilts the whole rig, e.g. to sit on a ramp.
    ///   - facing: 1 faces right, -1 left; values in between squash the figure mid-turn.
    static func draw(
        in graphics: GraphicsContext,
        at position: CGPoint,
        unit: CGFloat,
        rotation: Double = 0,
        facing: Double = 1,
        pose: SkaterPose,
        palette: SkaterPalette = SkaterPalette()
    ) {
        var g = graphics
        g.translateBy(x: position.x, y: position.y)
        g.rotate(by: .radians(rotation))
        let face = abs(facing) < 0.06 ? (facing < 0 ? -0.06 : 0.06) : facing
        g.scaleBy(x: unit * face, y: unit)

        let outline: CGFloat = 0.32
        let lean = pose.lean + pose.crouch * 0.3
        let hipY = -(4.75 - pose.crouch * 2.0)
        let pelvis = CGPoint(x: 0.05, y: hipY)
        let shoulder = pelvis + CGPoint(x: sin(lean) * 3.0, y: -cos(lean) * 3.0)
        let head = shoulder + CGPoint(x: sin(lean) * 1.55, y: -cos(lean) * 1.55)
        let backFoot = CGPoint(x: -1.7, y: -0.32)
        let frontFoot = CGPoint(x: 1.5, y: -0.32)

        drawBoard(in: g, pose: pose, palette: palette, outline: outline)

        // Back arm and leg sit behind the torso.
        let backHand = shoulder + CGPoint(
            x: sin(-(0.35 + pose.armsOut * 1.25) + pose.armSwing * 0.35) * 3.2,
            y: cos(-(0.35 + pose.armsOut * 1.25) + pose.armSwing * 0.35) * 3.2
        )
        drawArm(in: g, shoulder: shoulder, hand: backHand, bend: -1, palette: palette, outline: outline)
        drawLeg(in: g, hip: pelvis + CGPoint(x: -0.35, y: 0), foot: backFoot, bend: 1, palette: palette, outline: outline)
        drawLeg(in: g, hip: pelvis + CGPoint(x: 0.45, y: 0), foot: frontFoot, bend: -1, palette: palette, outline: outline)

        // Torso.
        var torso = Path()
        torso.addLines([pelvis, shoulder])
        g.stroke(torso, with: .color(palette.ink), style: SkateTheme.outline(2.0 + outline * 2))
        g.stroke(torso, with: .color(palette.shirt), style: SkateTheme.outline(2.0))

        // Head, cap and eye.
        let headRadius: CGFloat = 1.0
        let headPath = Path(ellipseIn: CGRect(x: head.x - headRadius, y: head.y - headRadius, width: headRadius * 2, height: headRadius * 2))
        g.fill(headPath, with: .color(palette.skin))
        g.stroke(headPath, with: .color(palette.ink), style: SkateTheme.outline(outline))
        var cap = Path()
        cap.addLines((0...12).map { step in
            let angle = Double.pi + Double.pi * Double(step) / 12
            return head + CGPoint(x: cos(angle) * 1.08, y: sin(angle) * 1.08 - 0.08)
        })
        cap.closeSubpath()
        g.fillOutlined(cap, palette.cap, outline: outline, ink: palette.ink)
        var brim = Path()
        brim.addLines([head + CGPoint(x: 0.3, y: -0.12), head + CGPoint(x: 1.75, y: -0.02)])
        g.stroke(brim, with: .color(palette.ink), style: SkateTheme.outline(0.42 + outline * 2))
        g.stroke(brim, with: .color(palette.cap), style: SkateTheme.outline(0.42))
        g.fill(Path(ellipseIn: CGRect(x: head.x + 0.42, y: head.y + 0.05, width: 0.26, height: 0.3)), with: .color(palette.ink))

        // Front arm, reaching for the nose during a grab.
        let reach = 0.35 + pose.armsOut * 1.25 + pose.armSwing * 0.35
        let restingHand = shoulder + CGPoint(x: sin(reach) * 3.2, y: cos(reach) * 3.2)
        let nose = CGPoint(x: 3.3, y: pose.boardDrop - 0.1)
        let frontHand = restingHand + (nose - restingHand) * CGFloat(pose.grab)
        drawArm(in: g, shoulder: shoulder, hand: frontHand, bend: 1, palette: palette, outline: outline)
    }

    private static func drawBoard(in graphics: GraphicsContext, pose: SkaterPose, palette: SkaterPalette, outline: CGFloat) {
        var g = graphics
        g.translateBy(x: 0, y: pose.boardDrop)
        g.rotate(by: .radians(-pose.boardTilt))
        // Kickflip rolls the board around its long axis; shuvit spins it flat. In side view
        // both read as the board squashing through zero and coming back (mirrored halfway).
        let roll = cos(2 * .pi * pose.flip)
        let turn = cos(2 * .pi * pose.spin)
        let scaleY = abs(roll) < 0.08 ? (roll < 0 ? -0.08 : 0.08) : roll
        let scaleX = abs(turn) < 0.08 ? (turn < 0 ? -0.08 : 0.08) : turn
        g.translateBy(x: 0, y: 0.45)
        g.scaleBy(x: scaleX, y: scaleY)
        g.translateBy(x: 0, y: -0.45)

        for x: CGFloat in [-2.6, 2.6] {
            let truck = Path(roundedRect: CGRect(x: x - 0.65, y: 0.15, width: 1.3, height: 0.45), cornerRadius: 0.12)
            g.fillOutlined(truck, SkateTheme.steel, outline: outline * 0.8, ink: palette.ink)
            let wheel = Path(ellipseIn: CGRect(x: x - 0.5, y: 0.45, width: 1.0, height: 1.0))
            g.fillOutlined(wheel, SkateTheme.offWhite, outline: outline * 0.8, ink: palette.ink)
        }

        var deck = Path()
        deck.addLines([CGPoint(x: -4.2, y: -0.5), CGPoint(x: -3.35, y: 0.05), CGPoint(x: 3.35, y: 0.05), CGPoint(x: 4.2, y: -0.5)])
        g.stroke(deck, with: .color(palette.ink), style: SkateTheme.outline(0.5 + outline * 2))
        g.stroke(deck, with: .color(roll < 0 ? palette.deckBottom : SkateTheme.wood), style: SkateTheme.outline(0.5))
    }

    private static func drawLeg(in g: GraphicsContext, hip: CGPoint, foot: CGPoint, bend: CGFloat, palette: SkaterPalette, outline: CGFloat) {
        let knee = joint(from: hip, to: foot, upper: 2.55, lower: 2.55, bend: bend)
        var leg = Path()
        leg.addLines([hip, knee, foot])
        g.stroke(leg, with: .color(palette.ink), style: SkateTheme.outline(1.15 + outline * 2))
        g.stroke(leg, with: .color(palette.pants), style: SkateTheme.outline(1.15))

        var shoe = Path()
        shoe.addLines([foot + CGPoint(x: -0.55, y: 0), foot + CGPoint(x: 0.65, y: 0)])
        g.stroke(shoe, with: .color(palette.ink), style: SkateTheme.outline(0.6 + outline * 2))
        g.stroke(shoe, with: .color(palette.shoes), style: SkateTheme.outline(0.6))
    }

    private static func drawArm(in g: GraphicsContext, shoulder: CGPoint, hand: CGPoint, bend: CGFloat, palette: SkaterPalette, outline: CGFloat) {
        let elbow = joint(from: shoulder, to: hand, upper: 1.75, lower: 1.65, bend: bend)
        var forearm = Path()
        forearm.addLines([elbow, hand])
        g.stroke(forearm, with: .color(palette.ink), style: SkateTheme.outline(0.62 + outline * 2))
        g.stroke(forearm, with: .color(palette.skin), style: SkateTheme.outline(0.62))
        var sleeve = Path()
        sleeve.addLines([shoulder, elbow])
        g.stroke(sleeve, with: .color(palette.ink), style: SkateTheme.outline(0.85 + outline * 2))
        g.stroke(sleeve, with: .color(palette.shirt), style: SkateTheme.outline(0.85))
    }

    /// Two-bone IK: where the knee/elbow sits so both segments reach from `start` toward `end`.
    private static func joint(from start: CGPoint, to end: CGPoint, upper: CGFloat, lower: CGFloat, bend: CGFloat) -> CGPoint {
        let delta = end - start
        let fullLength = max(delta.length, 0.001)
        let distance = min(fullLength, upper + lower - 0.001)
        let direction = delta * (1 / fullLength)
        let along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
        let height = sqrt(max(upper * upper - along * along, 0))
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        return start + direction * along + perpendicular * (height * bend)
    }
}
