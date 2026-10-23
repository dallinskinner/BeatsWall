//
//  DeepSeaCollection.swift
//  BeatsWall
//

import SwiftUI

enum DeepSeaCollection {
    static let collection = WallpaperCollection(
        id: "deepsea",
        name: "Deep Sea",
        tagline: "Bioluminescent life glowing in the dark.",
        symbol: "fish",
        accent: DeepSeaTheme.cyan,
        wallpapers: [
            Wallpaper(
                id: "deepsea.jellyfish-bloom",
                name: "Jellyfish Bloom",
                summary: "Glowing jellyfish pulse their bells and swim upward on the beat, trailing waving tentacles."
            ) { JellyfishBloomWallpaper(context: $0) },
            Wallpaper(
                id: "deepsea.whale-song",
                name: "Whale Song",
                summary: "A humpback glides through shafts of light, singing rings into the water with the melody."
            ) { WhaleSongWallpaper(context: $0) },
            Wallpaper(
                id: "deepsea.abyss-lure",
                name: "Abyss Lure",
                summary: "An anglerfish drifts out of the dark, its lure glowing with the bass while plankton glint around it."
            ) { AbyssLureWallpaper(context: $0) },
        ]
    )
}
