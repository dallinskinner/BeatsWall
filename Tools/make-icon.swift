#!/usr/bin/env swift
//
//  make-icon.swift
//  BeatsWall
//
//  Draws the BeatsWall app icon (a "B" built from equalizer bars) and writes every
//  macOS size into the asset catalog.
//
//  Usage: swift Tools/make-icon.swift            (from the repo root)
//

import AppKit
import CoreGraphics

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> CGColor {
    func channel(_ value: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((value >> shift) & 0xFF) / 255 }
    return CGColor(
        srgbRed: channel(a, 16) + (channel(b, 16) - channel(a, 16)) * t,
        green: channel(a, 8) + (channel(b, 8) - channel(a, 8)) * t,
        blue: channel(a, 0) + (channel(b, 0) - channel(a, 0)) * t,
        alpha: 1
    )
}

let magenta: UInt32 = 0xFF2E97
let orange: UInt32 = 0xFF8C42
let yellow: UInt32 = 0xFFD23F

func drawIcon(in ctx: CGContext) {
    // Work top-down like the rest of the app.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    // macOS icon grid: an 824 pt tile centered on the 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.45))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x0E1230))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let background = CGGradient(colorsSpace: space, colors: [color(0x0E1230), color(0x2A0A4A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])

    let center = CGPoint(x: 512, y: 512)
    let glow = CGGradient(colorsSpace: space, colors: [color(magenta, 0.42), color(magenta, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 400, options: [])

    // Beat-pulse rings radiating out from behind the letter.
    for (index, radius) in [CGFloat(318), 372, 424].enumerated() {
        let t = CGFloat(index) / 2
        ctx.setStrokeColor(mix(magenta, orange, t).copy(alpha: 0.38 - 0.11 * CGFloat(index))!)
        ctx.setLineWidth(16 - 4 * CGFloat(index))
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    // The "B": seven rounded bars. Stem plus two bowls, with ragged equalizer-style ends.
    let rows: [[(CGFloat, CGFloat)]] = [
        [(0, 5.2)],
        [(0, 1.9), (4.2, 6.0)],
        [(0, 1.9), (4.4, 6.1)],
        [(0, 5.6)],
        [(0, 1.9), (4.6, 6.5)],
        [(0, 1.9), (4.8, 6.6)],
        [(0, 6.0)],
    ]
    let letterWidth: CGFloat = 430
    let unit = letterWidth / 6.6
    let rowHeight: CGFloat = 76
    let barHeight: CGFloat = 60
    let left = center.x - letterWidth / 2
    let top = center.y - rowHeight * CGFloat(rows.count) / 2 + (rowHeight - barHeight) / 2

    ctx.setShadow(offset: .zero, blur: 36, color: color(magenta, 0.75))
    for (row, segments) in rows.enumerated() {
        let t = CGFloat(row) / CGFloat(rows.count - 1)
        let fill = t < 0.5 ? mix(magenta, orange, t * 2) : mix(orange, yellow, (t - 0.5) * 2)
        for (start, end) in segments {
            let bar = CGRect(x: left + start * unit, y: top + CGFloat(row) * rowHeight, width: (end - start) * unit, height: barHeight)
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
            ctx.setFillColor(fill)
            ctx.fillPath()
        }
    }
    // Soft highlight along the top of each bar.
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    for (row, segments) in rows.enumerated() {
        for (start, end) in segments {
            let bar = CGRect(x: left + start * unit + 14, y: top + CGFloat(row) * rowHeight + 9, width: (end - start) * unit - 28, height: 12)
            guard bar.width > 0 else { continue }
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.setFillColor(color(0xFFFFFF, 0.28))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = context.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let iconSet = URL(fileURLWithPath: "BeatsWall/Assets.xcassets/AppIcon.appiconset")
guard FileManager.default.fileExists(atPath: iconSet.path) else {
    fatalError("Run from the repo root: swift Tools/make-icon.swift")
}

// (point size, scale) pairs the asset catalog expects.
let slots: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (points, scale) in slots {
    let pixels = points * scale
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try render(size: pixels).write(to: iconSet.appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: iconSet.appendingPathComponent("Contents.json"))
print("Wrote \(slots.count) icons to \(iconSet.path)")
