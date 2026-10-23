//
//  WinterCollection.swift
//  BeatsWall
//

import SwiftUI

enum WinterCollection {
    static let collection = WallpaperCollection(
        id: "winter",
        name: "Winter Holidays",
        tagline: "Snowfall, twinkling lights and cozy glows for the holiday season.",
        symbol: "snowflake",
        accent: WinterTheme.blue,
        wallpapers: [
            Wallpaper(
                id: "winter.snowy-cabin",
                name: "Snowy Cabin",
                summary: "A log cabin in the pines. String lights blink in patterns that change every bar, and snow falls harder as the music swells."
            ) { SnowyCabinWallpaper(context: $0) },
            Wallpaper(
                id: "winter.snow-globe",
                name: "Snow Globe",
                summary: "A tiny village under glass. Every bass hit shakes the globe and sends the snow swirling."
            ) { SnowGlobeWallpaper(context: $0) },
            Wallpaper(
                id: "winter.twinkling-tree",
                name: "Twinkling Tree",
                summary: "Ornaments glow with the spectrum, the garland sparkles on the hi-hats and the star pulses on every beat."
            ) { TwinklingTreeWallpaper(context: $0) },
        ]
    )
}
