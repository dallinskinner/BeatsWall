//
//  MenuBarContent.swift
//  BeatsWall
//

import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var appState = appState

        ForEach(WallpaperCatalog.collections) { collection in
            Section(collection.name) {
                ForEach(collection.wallpapers) { wallpaper in
                    Toggle(wallpaper.name, isOn: Binding(
                        get: { appState.selectedWallpaperID == wallpaper.id },
                        set: { if $0 { appState.selectedWallpaperID = wallpaper.id } }
                    ))
                }
            }
        }

        Divider()

        Toggle("Shuffle Every Bar", isOn: $appState.isShuffling)
            .keyboardShortcut("s")
        Picker("Shuffle From", selection: $appState.shufflePool) {
            ForEach(AppState.ShufflePool.allCases) { pool in
                Text(pool.title).tag(pool)
            }
        }
        Toggle("Show Lyrics", isOn: $appState.showsLyrics)
            .keyboardShortcut("l")
        if appState.showsLyrics, let track = appState.lyrics.track {
            Text("♪ \(track.title) — \(track.artist)")
        }

        Divider()

        Toggle("Pause", isOn: $appState.isPaused)
            .keyboardShortcut("p")

        Button("Browse Collections…") {
            openWindow(id: "collections")
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit BeatsWall") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
