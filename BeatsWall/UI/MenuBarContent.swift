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

        Toggle("Concert Mode", isOn: $appState.isConcertMode)
            .keyboardShortcut("k")
        Picker("Stage", selection: $appState.concertStageID) {
            Text("Automatic").tag(String?.none)
            ForEach(ConcertShow.stages, id: \.self) { id in
                Text(WallpaperCatalog.wallpaper(id: id)?.name ?? id).tag(String?.some(id))
            }
        }

        if appState.isConcertMode {
            Text("🎤 \(appState.concert.summary)")
        }
        Button(StageImage.shared.image == nil ? "Stage Image…" : "Change Stage Image…") { StageImage.shared.choose() }
        if StageImage.shared.image != nil {
            Button("Remove Stage Image") { StageImage.shared.clear() }
        }

        Divider()

        Toggle("Shuffle Every Bar", isOn: $appState.isShuffling)
            .keyboardShortcut("s")
            .disabled(appState.isConcertMode)
        Picker("Shuffle From", selection: $appState.shufflePool) {
            ForEach(AppState.ShufflePool.allCases) { pool in
                Text(pool.title).tag(pool)
            }
        }
        .disabled(appState.isConcertMode)
        Toggle("Show Lyrics", isOn: $appState.showsLyrics)
            .keyboardShortcut("l")
        if appState.showsLyrics, let track = appState.lyrics.track {
            Text("♪ \(track.title) — \(track.artist)")
        }

        Divider()

        Toggle("Pause", isOn: $appState.isPaused)
            .keyboardShortcut("p")
        Toggle("Hide Desktop Icons", isOn: $appState.hidesDesktopIcons)
            .keyboardShortcut("h", modifiers: [.command, .shift])

        Divider()

        Button("Record Clip…") { open("clip") }
            .keyboardShortcut("r")
        Button("Browse Collections…") { open("collections") }
            .keyboardShortcut("b")
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Button("Send Feedback…") { open("feedback") }

        Divider()

        Text("BeatsWall \(BetaInfo.versionDescription)")

        Button("Quit BeatsWall") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func open(_ window: String) {
        openWindow(id: window)
        NSApp.activate()
    }
}
