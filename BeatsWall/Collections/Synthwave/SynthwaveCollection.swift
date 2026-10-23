//
//  SynthwaveCollection.swift
//  BeatsWall
//

import SwiftUI

enum SynthwaveCollection {
    static let collection = WallpaperCollection(
        id: "synthwave",
        name: "Synthwave",
        tagline: "Neon grids, chrome sunsets and endless night drives.",
        symbol: "sun.horizon",
        accent: SynthwaveTheme.magenta,
        wallpapers: [
            Wallpaper(
                id: "synthwave.outrun-grid",
                name: "Outrun Grid",
                summary: "A neon grid racing toward a striped sun, with wireframe mountains that rise with the spectrum."
            ) { OutrunGridWallpaper(context: $0) },
            Wallpaper(
                id: "synthwave.neon-palms",
                name: "Neon Palms",
                summary: "Palm silhouettes at sunset over rippling water, and a neon sign that flickers on the beat."
            ) { NeonPalmsWallpaper(context: $0) },
            Wallpaper(
                id: "synthwave.midnight-drive",
                name: "Midnight Drive",
                summary: "Cruising a neon highway. Taillights pulse with the bass and the skyline is an equalizer."
            ) { MidnightDriveWallpaper(context: $0) },
        ]
    )
}
