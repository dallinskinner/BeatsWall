//
//  SpaceCollection.swift
//  BeatsWall
//

import SwiftUI

enum SpaceCollection {
    static let collection = WallpaperCollection(
        id: "space",
        name: "Space",
        tagline: "Warp jumps, drifting nebulae and a ringed planet keeping time.",
        symbol: "sparkles",
        accent: SpaceTheme.teal,
        wallpapers: [
            Wallpaper(
                id: "space.warp-drive",
                name: "Warp Drive",
                summary: "Stars streak past faster as the music gets louder, jumping to warp on the big beats."
            ) { WarpDriveWallpaper(context: $0) },
            Wallpaper(
                id: "space.nebula",
                name: "Nebula",
                summary: "Glowing gas clouds that swirl with the melody and brighten with the bass, under twinkling stars."
            ) { NebulaWallpaper(context: $0) },
            Wallpaper(
                id: "space.ringed-planet",
                name: "Ringed Planet",
                summary: "Rings ripple with the spectrum and shimmer on each beat while moons orbit in time."
            ) { RingedPlanetWallpaper(context: $0) },
        ]
    )
}
