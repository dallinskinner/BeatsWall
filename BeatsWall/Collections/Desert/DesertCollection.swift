//
//  DesertCollection.swift
//  BeatsWall
//

import SwiftUI

enum DesertCollection {
    static let collection = WallpaperCollection(
        id: "desert",
        name: "Desert Night",
        tagline: "Campfires, giant moons and skies full of falling stars.",
        symbol: "moon.stars",
        accent: DesertTheme.fire,
        wallpapers: [
            Wallpaper(
                id: "desert.campfire",
                name: "Campfire",
                summary: "A crackling fire under the stars. Flames leap with the bass and sparks rise with the hi-hats."
            ) { CampfireWallpaper(context: $0) },
            Wallpaper(
                id: "desert.dune-moon",
                name: "Dune Moon",
                summary: "A camel caravan crosses moonlit dunes in step with the beat while sand streams off the crests."
            ) { DuneMoonWallpaper(context: $0) },
            Wallpaper(
                id: "desert.shooting-stars",
                name: "Shooting Stars",
                summary: "The Milky Way over desert mesas. Shooting stars fall on the beat and constellations draw themselves with the music."
            ) { ShootingStarsWallpaper(context: $0) },
        ]
    )
}
