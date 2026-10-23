//
//  HalloweenCollection.swift
//  BeatsWall
//

import SwiftUI

enum HalloweenCollection {
    static let collection = WallpaperCollection(
        id: "halloween",
        name: "Halloween",
        tagline: "Fog, moonlight and things that move with the music after dark.",
        symbol: "moon.haze",
        accent: HalloweenTheme.pumpkin,
        wallpapers: [
            Wallpaper(
                id: "halloween.haunted-house",
                name: "Haunted House",
                summary: "Windows flicker with the spectrum, bats burst from the attic on the beat and lightning strikes on the big hits."
            ) { HauntedHouseWallpaper(context: $0) },
            Wallpaper(
                id: "halloween.pumpkin-patch",
                name: "Pumpkin Patch",
                summary: "Jack-o'-lanterns glow with the bass and sing along, each to its own part of the song."
            ) { PumpkinPatchWallpaper(context: $0) },
            Wallpaper(
                id: "halloween.graveyard-rave",
                name: "Graveyard Rave",
                summary: "Skeletons dance among the tombstones while ghost-light beams sweep the sky in tempo."
            ) { GraveyardRaveWallpaper(context: $0) },
            Wallpaper(
                id: "halloween.ghost-choir",
                name: "Ghost Choir",
                summary: "Ghosts drifting through a misty forest. Each one sings a part, and they wail together on the beat."
            ) { GhostChoirWallpaper(context: $0) },
        ]
    )
}
