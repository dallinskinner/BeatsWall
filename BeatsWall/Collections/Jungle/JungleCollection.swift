//
//  JungleCollection.swift
//  BeatsWall
//

import SwiftUI

enum JungleCollection {
    static let collection = WallpaperCollection(
        id: "jungle",
        name: "Tropical Jungle",
        tagline: "Lush leaves, bright birds and warm light filtering through the canopy.",
        symbol: "leaf",
        accent: JungleTheme.leafLight,
        wallpapers: [
            Wallpaper(
                id: "jungle.canopy",
                name: "Canopy",
                summary: "Layers of giant leaves swaying with the melody while sunlight dapples through on the hi-hats."
            ) { CanopyWallpaper(context: $0) },
            Wallpaper(
                id: "jungle.parrot-party",
                name: "Parrot Party",
                summary: "Four parrots on a branch bobbing their heads on and off the beat, flaring their wings on the big hits."
            ) { ParrotPartyWallpaper(context: $0) },
            Wallpaper(
                id: "jungle.waterfall-pool",
                name: "Waterfall Pool",
                summary: "A misty waterfall pouring into a pool where glowing frogs puff their throats on the beat."
            ) { WaterfallPoolWallpaper(context: $0) },
        ]
    )
}
