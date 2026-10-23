//
//  ClaudeCollection.swift
//  BeatsWall
//

import SwiftUI

enum ClaudeCollection {
    static let collection = WallpaperCollection(
        id: "claude",
        name: "Claude",
        tagline: "Warm terracotta sparks, thoughtful glows and a terminal that grooves.",
        symbol: "sparkle",
        accent: ClaudeTheme.terracotta,
        wallpapers: [
            Wallpaper(
                id: "claude.spark-bloom",
                name: "Spark Bloom",
                summary: "A terracotta spark whose rays stretch with the spectrum and pulse on every kick."
            ) { SparkBloomWallpaper(context: $0) },
            Wallpaper(
                id: "claude.thinking",
                name: "Thinking",
                summary: "A calm field of glowing dots. Ripples follow the melody and rings bloom on the beat."
            ) { ThinkingWallpaper(context: $0) },
            Wallpaper(
                id: "claude.terminal",
                name: "Claude Code Terminal",
                summary: "A late-night terminal with a block-character spectrum analyzer and a spinner that keeps time."
            ) { ClaudeTerminalWallpaper(context: $0) },
            Wallpaper(
                id: "claude.spark-field",
                name: "Spark Field",
                summary: "Hundreds of tiny sparks drifting on the hi-hats and bursting outward on the kick."
            ) { SparkFieldWallpaper(context: $0) },
            Wallpaper(
                id: "claude.clawd",
                name: "Clawd",
                summary: "The Claude Code mascot hops on the kick, steps in time and throws its arms up when the chorus hits."
            ) { ClawdWallpaper(context: $0) },
        ]
    )
}
