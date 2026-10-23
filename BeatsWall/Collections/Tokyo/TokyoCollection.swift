//
//  TokyoCollection.swift
//  BeatsWall
//

import SwiftUI

enum TokyoCollection {
    static let collection = WallpaperCollection(
        id: "tokyo",
        name: "Neon Tokyo",
        tagline: "Rain-slick streets, glowing signs and the last train home.",
        symbol: "building.2",
        accent: TokyoTheme.pink,
        wallpapers: [
            Wallpaper(
                id: "tokyo.rainy-crossing",
                name: "Rainy Crossing",
                summary: "Neon signs flicker with the spectrum above a wet crossing, mirrored in the puddles as umbrellas step in time."
            ) { RainyCrossingWallpaper(context: $0) },
            Wallpaper(
                id: "tokyo.midnight-train",
                name: "Midnight Train",
                summary: "An elevated train glides past on the downbeat while the skyline's windows light up like an equalizer."
            ) { MidnightTrainWallpaper(context: $0) },
            Wallpaper(
                id: "tokyo.ramen-alley",
                name: "Ramen Alley",
                summary: "A glowing ramen stall in a narrow alley, with lanterns swaying to the melody and a cat flicking its tail on the beat."
            ) { RamenAlleyWallpaper(context: $0) },
        ]
    )
}
