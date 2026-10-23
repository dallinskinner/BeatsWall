//
//  CyberpunkCollection.swift
//  BeatsWall
//

import SwiftUI

enum CyberpunkCollection {
    static let collection = WallpaperCollection(
        id: "cyber",
        name: "Cyberpunk",
        tagline: "Glitching holograms, a city that never sleeps and code that falls like rain.",
        symbol: "cpu",
        accent: CyberTheme.magenta,
        wallpapers: [
            Wallpaper(
                id: "cyber.hologram",
                name: "Hologram",
                summary: "A wireframe globe projected above a neon grid. It spins with the music and glitches on the big beats."
            ) { HologramWallpaper(context: $0) },
            Wallpaper(
                id: "cyber.megacity",
                name: "Megacity",
                summary: "Towering neon city with flying cars, and giant ad screens that flash with the spectrum."
            ) { MegacityWallpaper(context: $0) },
            Wallpaper(
                id: "cyber.code-rain",
                name: "Code Rain",
                summary: "Columns of strange glyphs pour down faster as the music gets louder, flaring white on the beat."
            ) { CodeRainWallpaper(context: $0) },
        ]
    )
}
