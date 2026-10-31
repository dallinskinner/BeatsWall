//
//  BrandCollection.swift
//  BeatsWall
//

import SwiftUI

enum BrandCollection {
    static let collection = WallpaperCollection(
        id: "beatswall",
        name: "BeatsWall",
        tagline: "The house collection: the B in lights, glowing ripples and Woofie the speaker.",
        symbol: "waveform",
        accent: BrandTheme.magenta,
        wallpapers: [
            Wallpaper(
                id: "beatswall.beat-b",
                name: "Beat B",
                summary: "The BeatsWall B, built from equalizer bars that stretch with the spectrum and flare on every kick."
            ) { BeatBWallpaper(context: $0) },
            Wallpaper(
                id: "beatswall.ripple-grid",
                name: "Ripple Grid",
                summary: "A field of glowing dots. Ripples follow the melody and rings bloom out on the beat."
            ) { RippleGridWallpaper(context: $0) },
            Wallpaper(
                id: "beatswall.terminal",
                name: "BeatsWall Terminal",
                summary: "A late-night terminal with a block-character spectrum analyzer and a spinner that keeps time."
            ) { BrandTerminalWallpaper(context: $0) },
            Wallpaper(
                id: "beatswall.spark-field",
                name: "Spark Field",
                summary: "Hundreds of tiny sparks drifting on the hi-hats and bursting outward on the kick."
            ) { SparkFieldWallpaper(context: $0) },
            Wallpaper(
                id: "beatswall.woofie",
                name: "Woofie",
                summary: "Woofie the speaker pumps its woofer with the bass, hops on the kick and throws its arms up when the chorus hits."
            ) { WoofieWallpaper(context: $0) },
        ]
    )

    /// The Claude collection's old wallpaper ids, so saved choices carry over.
    static let formerIDs = [
        "claude.spark-bloom": "beatswall.beat-b",
        "claude.thinking": "beatswall.ripple-grid",
        "claude.terminal": "beatswall.terminal",
        "claude.spark-field": "beatswall.spark-field",
        "claude.clawd": "beatswall.woofie",
    ]
}
