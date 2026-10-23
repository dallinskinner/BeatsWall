//
//  NatureCollection.swift
//  BeatsWall
//

import SwiftUI

enum NatureCollection {
    static let collection = WallpaperCollection(
        id: "nature",
        name: "Ocean & Nature",
        tagline: "Moonlit swells, firefly meadows and rain on the window.",
        symbol: "water.waves",
        accent: Color(hex: 0x3FA7A3),
        wallpapers: [
            Wallpaper(
                id: "nature.swell",
                name: "Swell",
                summary: "Moonlit waves that rise with the bass, with foam glinting on the hi-hats."
            ) { SwellWallpaper(context: $0) },
            Wallpaper(
                id: "nature.firefly-meadow",
                name: "Firefly Meadow",
                summary: "Dusk grass swaying with the melody while fireflies blink, and some flash together on the beat."
            ) { FireflyMeadowWallpaper(context: $0) },
            Wallpaper(
                id: "nature.rainy-window",
                name: "Rainy Window",
                summary: "City lights blurred behind wet glass. Lights pulse with the spectrum and drops run down on the beat."
            ) { RainyWindowWallpaper(context: $0) },
        ]
    )
}
