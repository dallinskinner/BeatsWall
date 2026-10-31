//
//  ConcertCollection.swift
//  BeatsWall
//

import SwiftUI

enum ConcertCollection {
    static let collection = WallpaperCollection(
        id: "concert",
        name: "Concert",
        tagline: "Front row at the biggest show of your life.",
        symbol: "music.mic",
        accent: ConcertTheme.magenta,
        wallpapers: [
            Wallpaper(
                id: "concert.main-stage",
                name: "Main Stage",
                summary: "A festival stage with sweeping moving heads and an LED wall. When the song drops, confetti and CO2 blast over the crowd."
            ) { MainStageWallpaper(context: $0) },
            Wallpaper(
                id: "concert.headliner",
                name: "Headliner",
                summary: "A rock band backlit in smoke. The drummer hits every beat, and flame columns erupt on the big hits."
            ) { HeadlinerWallpaper(context: $0) },
            Wallpaper(
                id: "concert.lights-up",
                name: "Lights Up",
                summary: "A stadium full of phone lights swaying to the song, with fireworks over the rim on the loud parts."
            ) { LightsUpWallpaper(context: $0) },
            Wallpaper(
                id: "concert.laser-rave",
                name: "Laser Rave",
                summary: "Lasers cut through warehouse fog and change shape every bar. On the drop, it becomes a spinning laser tunnel."
            ) { LaserRaveWallpaper(context: $0) },
        ]
    )
}
