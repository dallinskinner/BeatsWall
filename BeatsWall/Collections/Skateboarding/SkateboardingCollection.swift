//
//  SkateboardingCollection.swift
//  BeatsWall
//

import SwiftUI

enum SkateboardingCollection {
    static let collection = WallpaperCollection(
        id: "skate",
        name: "Skateboarding",
        tagline: "Deck-graphic colors, airs on the kick and a VHS tape that glitches with the bass.",
        symbol: "figure.skateboarding",
        accent: SkateTheme.orange,
        wallpapers: [
            Wallpaper(
                id: "skate.halfpipe",
                name: "Halfpipe Session",
                summary: "A skater pumps a halfpipe in time with the music, launching higher airs on bigger bass."
            ) { HalfpipeSessionWallpaper(context: $0) },
            Wallpaper(
                id: "skate.night-street",
                name: "Night Street Line",
                summary: "Cruising a city at night, ollieing obstacles on the beat while the skyline lights up like an equalizer."
            ) { NightStreetLineWallpaper(context: $0) },
            Wallpaper(
                id: "skate.vhs-tape",
                name: "VHS Skate Tape",
                summary: "A ledge line off a worn 90s tape. Tracking glitches and color bleed kick in on every beat."
            ) { VHSSkateTapeWallpaper(context: $0) },
            Wallpaper(
                id: "skate.grip-stickers",
                name: "Grip & Stickers",
                summary: "Grip tape glinting with the hi-hats, stickers bouncing on the beat and bolts glowing with the bass."
            ) { GripAndStickersWallpaper(context: $0) },
        ]
    )
}
