//
//  BeatsWallLogo.swift
//  BeatsWall
//

import AppKit
import SwiftUI

/// The "B built from equalizer bars" mark. Same geometry as the app icon (`Tools/make-icon.swift`).
enum BeatsWallLogo {
    /// Bar segments per row, in units across a 6.6-unit-wide letter.
    static let rows: [[(start: CGFloat, end: CGFloat)]] = [
        [(0, 5.2)],
        [(0, 1.9), (4.2, 6.0)],
        [(0, 1.9), (4.4, 6.1)],
        [(0, 5.6)],
        [(0, 1.9), (4.6, 6.5)],
        [(0, 1.9), (4.8, 6.6)],
        [(0, 6.0)],
    ]

    /// Monochrome template image for the menu bar, so it adapts to light/dark and highlight.
    static let menuBarImage: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            let rowHeight: CGFloat = 2.2
            let barHeight: CGFloat = 1.7
            let unit: CGFloat = 13.5 / 6.6
            let left = (size.width - 6.6 * unit) / 2
            let top = (size.height - rowHeight * CGFloat(rows.count)) / 2
            NSColor.black.setFill()
            for (row, segments) in rows.enumerated() {
                for segment in segments {
                    let rect = NSRect(x: left + segment.start * unit, y: top + CGFloat(row) * rowHeight, width: (segment.end - segment.start) * unit, height: barHeight)
                    NSBezierPath(roundedRect: rect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
