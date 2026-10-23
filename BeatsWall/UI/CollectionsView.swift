//
//  CollectionsView.swift
//  BeatsWall
//

import SwiftUI

struct CollectionsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCollectionID: String? = WallpaperCatalog.collections.first?.id

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            List(WallpaperCatalog.collections, selection: $selectedCollectionID) { collection in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(collection.name)
                        Text("\(collection.wallpapers.count) wallpapers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: collection.symbol)
                        .foregroundStyle(collection.accent)
                }
                .padding(.vertical, 4)
            }
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 36, height: 36)
                    Text("BeatsWall")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .navigationTitle("Collections")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            if let collection = WallpaperCatalog.collections.first(where: { $0.id == selectedCollectionID }) {
                CollectionDetailView(collection: collection)
            } else {
                ContentUnavailableView("Choose a Collection", systemImage: "square.grid.2x2")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $appState.isShuffling) {
                    Label("Shuffle", systemImage: "shuffle")
                }
                .help("Switch to a random wallpaper every bar")
                Toggle(isOn: $appState.showsLyrics) {
                    Label("Lyrics", systemImage: "quote.bubble")
                }
                .help("Show synced lyrics for the song playing in Music or Spotify")
                Toggle(isOn: $appState.isPaused) {
                    Label("Pause", systemImage: appState.isPaused ? "play.fill" : "pause.fill")
                }
                .help(appState.isPaused ? "Resume wallpaper" : "Pause wallpaper")
            }
        }
    }
}

private struct CollectionDetailView: View {
    let collection: WallpaperCollection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(collection.name, systemImage: collection.symbol)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(collection.accent)
                    Text(collection.tagline)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                AudioStatusView()
                LyricsStatusView()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20)], spacing: 28) {
                    ForEach(collection.wallpapers) { wallpaper in
                        WallpaperCard(wallpaper: wallpaper, accent: collection.accent)
                    }
                }
            }
            .padding(28)
        }
        .navigationTitle(collection.name)
    }
}

private struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let accent: Color
    @Environment(AppState.self) private var appState

    private var isSelected: Bool { appState.selectedWallpaperID == wallpaper.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.black
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay {
                    wallpaper.makeView(WallpaperContext(source: SimulatedAudioSource.shared, isPaused: false, isPreview: true))
                }
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? accent : .primary.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(wallpaper.name)
                        .font(.headline)
                    Text(wallpaper.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if isSelected {
                    Label("On Desktop", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundStyle(accent)
                        .help("Current wallpaper")
                } else {
                    Button("Set") { appState.selectedWallpaperID = wallpaper.id }
                        .buttonStyle(.bordered)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { appState.selectedWallpaperID = wallpaper.id }
    }
}

private struct AudioStatusView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    private static let privacySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            switch appState.audioStatus {
            case .failed(let message):
                banner(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Couldn't capture system audio",
                    detail: "\(message) Your wallpaper is dancing to a demo beat for now.",
                    showsSettings: true
                )
            case .stopped:
                Label("Paused", systemImage: "pause.circle")
                    .foregroundStyle(.secondary)
            case .listening where appState.liveAudio.secondsSinceSignal > 4:
                banner(
                    symbol: "ear",
                    title: "Waiting for music",
                    detail: "Play something in Spotify, Apple Music or a browser. If music is playing and nothing reacts, allow BeatsWall under Privacy & Security › Screen & System Audio Recording.",
                    showsSettings: true
                )
            case .listening:
                let bpm = appState.liveAudio.read().bpm
                Label(bpm > 0 ? "Listening · \(Int(bpm.rounded())) BPM" : "Listening", systemImage: "waveform")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func banner(symbol: String, title: String, detail: String, showsSettings: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if showsSettings {
                    Button("Open Privacy Settings") { openURL(Self.privacySettings) }
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 10))
    }
}

private struct LyricsStatusView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    private static let automationSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!

    var body: some View {
        if appState.showsLyrics {
            let lyrics = appState.lyrics
            switch lyrics.status {
            case .needsPermission(let player):
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow BeatsWall to read \(player)").font(.headline)
                        Text("Lyrics need to know which song is playing. Turn on BeatsWall › \(player) under Privacy & Security › Automation.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Automation Settings") { openURL(Self.automationSettings) }
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.orange.opacity(0.08), in: .rect(cornerRadius: 10))
            default:
                Label(message(for: lyrics), systemImage: "quote.bubble")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func message(for lyrics: LyricsController) -> String {
        let song = lyrics.track.map { "\($0.title) — \($0.artist)" } ?? ""
        switch lyrics.status {
        case .idle: return "Lyrics paused"
        case .nothingPlaying: return "Lyrics: play a song in Apple Music or Spotify"
        case .searching: return "Finding lyrics for \(song)…"
        case .showing: return "Lyrics: \(song)"
        case .instrumental: return "\(song) is instrumental"
        case .notFound: return "No synced lyrics found for \(song)"
        case .failed: return "Couldn't reach the lyrics service"
        case .needsPermission: return ""
        }
    }
}
