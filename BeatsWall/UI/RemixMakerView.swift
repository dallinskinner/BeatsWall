//
//  RemixMakerView.swift
//  BeatsWall
//
//  Find songs, line them up, and make a remix that plays as a live show on the desktop.
//

import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class RemixMakerModel {
    var query = ""
    private(set) var results: [CatalogSong] = []
    private(set) var isSearching = false
    var tracks: [RemixTrack] = []
    var name = "My Remix"
    private(set) var isBuilding = false
    private(set) var progressText = ""
    private(set) var progress = 0.0
    var message: String?
    private(set) var saved: [SavedRemix] = RemixLibrary.all()
    private(set) var previewingID: Int?

    @ObservationIgnored private var engineTask: Task<RemixPlan, Error>?
    @ObservationIgnored private var previewPlayer: AVPlayer?
    @ObservationIgnored private let reader = NowPlayingReader()

    func search() {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        message = nil
        Task {
            do {
                results = try await SongSearch.search(term)
                if results.isEmpty { message = "No songs with previews found for \"\(term)\"." }
            } catch {
                message = "Couldn't search Apple Music. Check your internet connection."
            }
            isSearching = false
        }
    }

    func togglePreview(_ song: CatalogSong) {
        previewPlayer?.pause()
        if previewingID == song.id {
            previewingID = nil
            return
        }
        guard let url = song.previewUrl else { return }
        let player = AVPlayer(url: url)
        player.volume = 0.6
        player.play()
        previewPlayer = player
        previewingID = song.id
    }

    func stopPreview() {
        previewPlayer?.pause()
        previewingID = nil
    }

    func add(_ song: CatalogSong) {
        var track = RemixTrack(song: song)
        tracks.append(track)
        let id = track.id
        Task {
            await track.loadColors()
            if let index = tracks.firstIndex(where: { $0.id == id }) { tracks[index].colors = track.colors }
        }
    }

    func addFiles(_ urls: [URL]) {
        Task {
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                let info = await ClipExporter.songInfo(for: url)
                if accessing { url.stopAccessingSecurityScopedResource() }
                tracks.append(RemixTrack(file: url, title: info.title, artist: info.artist ?? ""))
            }
        }
    }

    func addCurrentSong() {
        Task {
            guard let file = await reader.musicFile(), FileManager.default.isReadableFile(atPath: file.path) else {
                message = "Play a song from your Music library first. Streamed Apple Music songs can't be added this way; search for them instead."
                return
            }
            addFiles([file])
        }
    }

    func make(then play: @escaping (SavedRemix) -> Void) {
        guard !tracks.isEmpty, !isBuilding else { return }
        stopPreview()
        let tracks = tracks
        let name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Remix" : name
        isBuilding = true
        message = nil
        progressText = "Getting songs…"
        progress = 0
        Task {
            // Files picked by hand stay readable while the remix is made.
            let opened = tracks.compactMap { track -> URL? in
                if case .file(let url) = track.source, url.startAccessingSecurityScopedResource() { return url }
                return nil
            }
            defer { opened.forEach { $0.stopAccessingSecurityScopedResource() } }
            do {
                let inputs = try await RemixLibrary.prepare(tracks)
                let folder = RemixLibrary.newFolder(named: name)
                let task = Task.detached(priority: .userInitiated) { [weak self] in
                    try RemixEngine.build(inputs, name: name, folder: folder) { stage, value in
                        Task { @MainActor in
                            self?.progressText = stage
                            self?.progress = value
                        }
                    }
                }
                engineTask = task
                _ = try await task.value
                saved = RemixLibrary.all()
                if let remix = saved.first(where: { $0.folder == folder }) { play(remix) }
            } catch is CancellationError {
                message = nil
            } catch {
                message = "Couldn't make the remix: \(error.localizedDescription)"
            }
            engineTask = nil
            isBuilding = false
        }
    }

    func cancel() {
        engineTask?.cancel()
    }

    func delete(_ remix: SavedRemix) {
        RemixLibrary.delete(remix)
        saved = RemixLibrary.all()
    }
}

struct RemixMakerView: View {
    @Environment(AppState.self) private var appState
    @State private var model = RemixMakerModel()
    @State private var isChoosingFiles = false

    var body: some View {
        HStack(spacing: 0) {
            finder
                .frame(width: 400)
            Divider()
            remix
                .frame(maxWidth: .infinity)
        }
        .frame(width: 960, height: 640)
        .fileImporter(isPresented: $isChoosingFiles, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.addFiles(urls) }
        }
        .onDisappear { model.stopPreview() }
    }

    // MARK: - Finding songs

    private var finder: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 10) {
            Text("Find songs")
                .font(.headline)
            HStack {
                TextField("Search Apple Music", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.search() }
                if model.isSearching { ProgressView().controlSize(.small) }
            }
            List(model.results) { song in
                HStack(spacing: 10) {
                    AsyncImage(url: song.artworkUrl100) { image in
                        image.resizable()
                    } placeholder: {
                        Color.secondary.opacity(0.15)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.trackName).lineLimit(1)
                        Text([song.artistName, song.primaryGenreName].compactMap(\.self).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        model.togglePreview(song)
                    } label: {
                        Image(systemName: model.previewingID == song.id ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Listen to the preview")
                    Button("Add") { model.add(song) }
                }
            }
            .overlay {
                if model.results.isEmpty, !model.isSearching {
                    Text("Search for a song or artist.\nApple Music songs use their 30-second previews.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Add from Library…") { isChoosingFiles = true }
                Button("Add Current Song") { model.addCurrentSong() }
                    .help("The song playing in Apple Music, if it's a file in your library")
            }
        }
        .padding(16)
    }

    // MARK: - The remix

    private var remix: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your remix")
                    .font(.headline)
                Spacer()
                TextField("Name", text: $model.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            List {
                Section("Intro → \(model.tracks.count == 1 ? "1 song" : "\(model.tracks.count) songs") → Outro") {
                    ForEach($model.tracks) { $track in
                        HStack(spacing: 10) {
                            Text("\((model.tracks.firstIndex { $0.id == track.id } ?? 0) + 1)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).lineLimit(1)
                                Text("\(track.artist) · \(track.isPreview ? "Preview" : "Full song")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Picker("Stage", selection: $track.stageID) {
                                Text("Automatic").tag(String?.none)
                                ForEach(ConcertShow.stages, id: \.self) { id in
                                    Text(WallpaperCatalog.wallpaper(id: id)?.name ?? id).tag(String?.some(id))
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            Button {
                                model.tracks.removeAll { $0.id == track.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onMove { model.tracks.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .frame(minHeight: 220)
            .overlay {
                if model.tracks.isEmpty {
                    Text("Add songs from the left. Drag to change the order.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                if model.isBuilding {
                    ProgressView(value: model.progress).frame(width: 160)
                    Text(model.progressText).lineLimit(1)
                    Spacer()
                    Button("Cancel") { model.cancel() }
                } else {
                    if let message = model.message {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Make Remix") { model.make { appState.remix.play($0) } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.tracks.isEmpty)
                }
            }
            .frame(minHeight: 28)

            Divider()
            Text("Saved remixes")
                .font(.headline)
            List(model.saved) { saved in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(saved.plan.name)
                        Text("\(saved.plan.sections.filter { $0.kind == .song }.count) songs · \(Int(saved.plan.duration.rounded()))s · \(Int(saved.plan.bpm.rounded())) BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if appState.remix.remix == saved {
                        Button("Stop") { appState.remix.stop() }
                    } else {
                        Button("Play") { appState.remix.play(saved) }
                    }
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([saved.audioURL])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                    Button {
                        if appState.remix.remix == saved { appState.remix.stop() }
                        model.delete(saved)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete")
                }
            }
            .frame(minHeight: 120)
            Text("Remixes are for listening here, as a live show on your desktop. Songs from Apple Music use their 30-second previews.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
