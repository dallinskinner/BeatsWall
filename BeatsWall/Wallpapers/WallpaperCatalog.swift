//
//  WallpaperCatalog.swift
//  BeatsWall
//

import Foundation

/// Every collection that ships with the app. Add new collections here.
enum WallpaperCatalog {
    static let collections: [WallpaperCollection] = [
        ClaudeCollection.collection,
        SkateboardingCollection.collection,
        SynthwaveCollection.collection,
        SpaceCollection.collection,
        NatureCollection.collection,
        LofiCollection.collection,
        HalloweenCollection.collection,
        ArcadeCollection.collection,
        TokyoCollection.collection,
        WinterCollection.collection,
    ]

    static let defaultWallpaperID = "claude.spark-bloom"

    static func wallpaper(id: String) -> Wallpaper? {
        for collection in collections {
            if let wallpaper = collection.wallpapers.first(where: { $0.id == id }) {
                return wallpaper
            }
        }
        return nil
    }
}
