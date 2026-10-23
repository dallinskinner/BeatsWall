//
//  ArcadeCollection.swift
//  BeatsWall
//

import SwiftUI

enum ArcadeCollection {
    static let collection = WallpaperCollection(
        id: "arcade",
        name: "Retro Arcade",
        tagline: "Pixel-art games that play themselves to the beat, on a glowing CRT.",
        symbol: "gamecontroller",
        accent: ArcadeTheme.yellow,
        wallpapers: [
            Wallpaper(
                id: "arcade.maze-chase",
                name: "Maze Chase",
                summary: "A hungry chomper clears a maze two tiles per beat with bugs on its tail. Power pellets pulse with the bass."
            ) { MazeChaseWallpaper(context: $0) },
            Wallpaper(
                id: "arcade.star-shooter",
                name: "Star Shooter",
                summary: "Your ship fires on every beat at a marching swarm of pixel bugs while the starfield speeds up with the music."
            ) { StarShooterWallpaper(context: $0) },
            Wallpaper(
                id: "arcade.beat-runner",
                name: "Beat Runner",
                summary: "A little robot runs a side-scrolling level, jumping pipes and pits right on the beat."
            ) { BeatRunnerWallpaper(context: $0) },
        ]
    )
}
