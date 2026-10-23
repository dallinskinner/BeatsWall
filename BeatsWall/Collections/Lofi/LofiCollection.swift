//
//  LofiCollection.swift
//  BeatsWall
//

import SwiftUI

enum LofiCollection {
    static let collection = WallpaperCollection(
        id: "lofi",
        name: "Lo-fi Chill",
        tagline: "Cozy rooms, warm lamps and rooftops at golden hour, for beats to relax to.",
        symbol: "cup.and.saucer",
        accent: LofiTheme.lamp,
        wallpapers: [
            Wallpaper(
                id: "lofi.late-night-desk",
                name: "Late Night Desk",
                summary: "Rain on the window, a lamp that glows with the music, steaming coffee and a cat tapping its tail on the beat."
            ) { LateNightDeskWallpaper(context: $0) },
            Wallpaper(
                id: "lofi.vinyl-room",
                name: "Vinyl Room",
                summary: "A record spinning at 33⅓, speakers pushing with the bass and fairy lights twinkling on the hi-hats."
            ) { VinylRoomWallpaper(context: $0) },
            Wallpaper(
                id: "lofi.rooftop-sunset",
                name: "Rooftop Sunset",
                summary: "Golden hour over the city: birds flap in tempo and windows switch on with the spectrum."
            ) { RooftopSunsetWallpaper(context: $0) },
        ]
    )
}
