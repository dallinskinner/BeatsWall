//
//  NebulaWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct NebulaWallpaper: View {
    let context: WallpaperContext
    @State private var flow = PhaseClock()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            AudioTimeline(context: context) { frame in
                let audio = frame.audio
                let phase = flow.advance(to: frame.time, speed: 0.4 + 2.2 * Double(audio.mid))
                ZStack {
                    Rectangle()
                        .fill(SpaceTheme.void)
                        .colorEffect(ShaderLibrary.nebula(
                            .float2(size),
                            .float(phase),
                            .float(Double(audio.bass)),
                            .color(SpaceTheme.violet),
                            .color(SpaceTheme.pink),
                            .color(SpaceTheme.teal)
                        ))
                    Canvas { graphics, size in
                        graphics.blendMode = .plusLighter
                        SpaceTheme.drawStars(
                            in: &graphics, size: size, count: context.isPreview ? 120 : 260,
                            audio: audio, time: frame.time, drift: CGFloat(phase) * min(size.width, size.height) * 0.004
                        )
                    }
                }
            }
        }
    }
}
