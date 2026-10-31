//
//  WallpaperCatalog.swift
//  BeatsWall
//

import Foundation

/// Every collection that ships with the app. Add new collections here.
enum WallpaperCatalog {
    static let collections: [WallpaperCollection] = [
        BrandCollection.collection,
        ConcertCollection.collection,
        SkateboardingCollection.collection,
        SynthwaveCollection.collection,
        SpaceCollection.collection,
        NatureCollection.collection,
        LofiCollection.collection,
        HalloweenCollection.collection,
        ArcadeCollection.collection,
        TokyoCollection.collection,
        WinterCollection.collection,
        DeepSeaCollection.collection,
        MinimalCollection.collection,
        CyberpunkCollection.collection,
        JungleCollection.collection,
        DesertCollection.collection,
    ]

    static let defaultWallpaperID = "beatswall.beat-b"

    /// The id a wallpaper goes by now, for ids saved before it was renamed.
    static func currentID(_ id: String) -> String {
        BrandCollection.formerIDs[id] ?? id
    }

    static func wallpaper(id: String) -> Wallpaper? {
        let id = currentID(id)
        for collection in collections {
            if let wallpaper = collection.wallpapers.first(where: { $0.id == id }) {
                return wallpaper
            }
        }
        return nil
    }
}
