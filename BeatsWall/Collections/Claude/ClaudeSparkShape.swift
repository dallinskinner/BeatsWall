//
//  ClaudeSparkShape.swift
//  BeatsWall
//

import SwiftUI

/// A hand-drawn-feeling starburst: rounded, slightly flared rays radiating from the center.
struct ClaudeSparkShape: Shape {
    struct Ray {
        /// Radians, 0 pointing right.
        var angle: Double
        /// Fraction of the shape's radius, 0...1.
        var length: CGFloat
    }

    var rays: [Ray]
    /// Half-width of a ray near the center, as a fraction of the radius.
    var baseWidth: CGFloat = 0.06
    /// Half-width of a ray at its rounded tip, as a fraction of the radius.
    var tipWidth: CGFloat = 0.085

    /// Fixed irregularity so the spark feels organic rather than mechanical.
    static let restingLengths: [CGFloat] = [1.0, 0.82, 0.94, 0.78, 0.97, 0.86, 0.99, 0.8, 0.91, 0.76, 0.95, 0.84]
    static let angleJitter: [Double] = [0, 0.05, -0.04, 0.03, -0.02, 0.06, -0.05, 0.02, 0.04, -0.03, 0.01, -0.06]

    /// The 12-ray spark, with each ray scaled by `energy(rayIndex)` (0...1).
    static func spark(energy: (Int) -> CGFloat = { _ in 0 }) -> ClaudeSparkShape {
        let count = restingLengths.count
        let rays = (0..<count).map { index in
            Ray(
                angle: Double(index) / Double(count) * 2 * .pi + angleJitter[index] - .pi / 2,
                length: restingLengths[index] * (0.62 + 0.38 * energy(index))
            )
        }
        return ClaudeSparkShape(rays: rays)
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for ray in rays {
            let direction = CGPoint(x: cos(ray.angle), y: sin(ray.angle))
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let base = center
            let tip = center + direction * (radius * max(ray.length, 0.12))
            let w0 = radius * baseWidth
            let w1 = radius * tipWidth

            path.move(to: base + normal * w0)
            path.addLine(to: tip + normal * w1)
            path.addQuadCurve(to: tip - normal * w1, control: tip + direction * (w1 * 2))
            path.addLine(to: base - normal * w0)
            path.addQuadCurve(to: base + normal * w0, control: base - direction * (w0 * 2))
            path.closeSubpath()
        }
        return path
    }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
private func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
private func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }
