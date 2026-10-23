//
//  MinimalCollection.swift
//  BeatsWall
//

import SwiftUI

enum MinimalCollection {
    static let collection = WallpaperCollection(
        id: "minimal",
        name: "Abstract Minimal",
        tagline: "Calm shapes and soft color that move with the music without stealing focus.",
        symbol: "circle.grid.3x3",
        accent: MinimalTheme.lilac,
        wallpapers: [
            Wallpaper(
                id: "minimal.breathing-rings",
                name: "Breathing Rings",
                summary: "Concentric pastel rings, each one a slice of the spectrum, breathing gently on the beat."
            ) { BreathingRingsWallpaper(context: $0) },
            Wallpaper(
                id: "minimal.bar-grid",
                name: "Bar Grid",
                summary: "A precise mirrored equalizer of rounded bars on a quiet dot grid, with four dots counting the bar."
            ) { BarGridWallpaper(context: $0) },
            Wallpaper(
                id: "minimal.gradient-blobs",
                name: "Gradient Blobs",
                summary: "Soft color blobs drifting and melting together, swelling with their part of the music."
            ) { GradientBlobsWallpaper(context: $0) },
        ]
    )
}
