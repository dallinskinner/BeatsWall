//
//  LightShowCollection.swift
//  BeatsWall
//

import SwiftUI

enum LightShowCollection {
    static let collection = WallpaperCollection(
        id: "lightshow",
        name: "Light Show",
        tagline: "Lasers, spotlights and fog: the light show, with nothing in the way.",
        symbol: "light.beacon.max",
        accent: ConcertTheme.laserGreen,
        wallpapers: [
            Wallpaper(
                id: "lightshow.laser-show",
                name: "Laser Show",
                summary: "Lasers in black fog over a mirror floor, with a rippling laser sky when the song drops."
            ) { LaserShowWallpaper(context: $0) },
            Wallpaper(
                id: "lightshow.spotlight-rig",
                name: "Spotlight Rig",
                summary: "A wall of moving heads throwing patterned pools of light that sweep and chase to the beat."
            ) { SpotlightRigWallpaper(context: $0) },
            Wallpaper(
                id: "lightshow.light-tunnel",
                name: "Light Tunnel",
                summary: "A rush through arches of LED light. A new arch arrives on every beat."
            ) { LightTunnelWallpaper(context: $0) },
            Wallpaper(
                id: "lightshow.fog-room",
                name: "Fog Room",
                summary: "Beams from six angles cut through rolling fog, opening on the build and narrowing to pinpoints on the drop."
            ) { FogRoomWallpaper(context: $0) },
        ]
    )
}
