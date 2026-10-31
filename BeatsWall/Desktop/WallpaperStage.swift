//
//  WallpaperStage.swift
//  BeatsWall
//

import SwiftUI

/// A live wallpaper with everything layered on it: the Concert Mode look and synced lyrics.
/// Used by the desktop and by Show Mode.
struct WallpaperStage: View {
    let wallpaper: Wallpaper
    let isPaused: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            wallpaper
                .makeView(WallpaperContext(
                    source: appState.desktopSource, isPaused: isPaused, isPreview: false, frameRate: appState.frameRate,
                    look: appState.isConcertMode ? appState.concert.look : nil, isLight: appState.lightEffects
                ))
                // Particle counts are set when a wallpaper starts, so switching Light mode restarts it.
                .id("\(wallpaper.id)|\(appState.lightEffects)")
            if appState.showsLyrics {
                LyricsOverlay(lyrics: appState.lyrics, source: appState.desktopSource, isPaused: isPaused)
            }
        }
        .ignoresSafeArea()
    }
}
