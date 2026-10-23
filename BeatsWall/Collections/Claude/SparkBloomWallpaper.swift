//
//  SparkBloomWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct SparkBloomWallpaper: View {
    let context: WallpaperContext

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let unit = min(size.width, size.height)

            AudioTimeline(context: context) { frame in
                let audio = frame.audio
                let bass = Double(audio.bass)
                let pulse = Double(audio.beatPulse)
                // Slow drift, plus a smooth step forward on every beat.
                let rotation = frame.time * 0.03 + (Double(audio.beatCount) - pulse) * 0.09
                let sparkSize = unit * 0.56 * (0.92 + 0.12 * Double(audio.level) + 0.06 * pulse)
                let spark = ClaudeSparkShape.spark { CGFloat(audio.spectrum[min(2 + $0 * 2, AudioFeatures.binCount - 1)]) }

                ZStack {
                    RadialGradient(
                        colors: [ClaudeTheme.charcoal, ClaudeTheme.warmDark, ClaudeTheme.ink],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.7
                    )

                    // Bass halo.
                    Circle()
                        .fill(RadialGradient(
                            colors: [ClaudeTheme.terracotta.opacity(0.12 + 0.3 * bass), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: unit * 0.5
                        ))
                        .frame(width: unit * (0.9 + 0.5 * bass), height: unit * (0.9 + 0.5 * bass))

                    // Shockwave echo that expands and fades after each beat.
                    ClaudeSparkShape.spark()
                        .fill(ClaudeTheme.clay.opacity(0.4 * pulse))
                        .frame(width: sparkSize, height: sparkSize)
                        .scaleEffect(1 + 0.8 * (1 - pulse))
                        .rotationEffect(.radians(rotation - 0.15 * (1 - pulse)))

                    spark
                        .fill(ClaudeTheme.terracotta)
                        .frame(width: sparkSize, height: sparkSize)
                        .rotationEffect(.radians(rotation))
                        .shadow(color: ClaudeTheme.terracotta.opacity(0.35 + 0.4 * bass), radius: unit * (0.01 + 0.04 * bass))
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .colorEffect(ClaudeTheme.grain())
    }
}
