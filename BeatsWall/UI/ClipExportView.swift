//
//  ClipExportView.swift
//  BeatsWall
//

import SwiftUI
import UniformTypeIdentifiers

/// Pick a wallpaper, a song and a format, then render a clip to post.
struct ClipExportView: View {
    @Environment(AppState.self) private var appState
    @State private var settings = ClipSettings(wallpaperID: WallpaperCatalog.defaultWallpaperID)
    @State private var exporter = ClipExporter()
    @State private var isChoosingSong = false
    @State private var hasLoaded = false

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            preview
                .frame(width: 260)
            VStack(alignment: .leading, spacing: 0) {
                form
                Divider()
                footer
                    .padding(16)
            }
        }
        .padding(.leading, 24)
        .padding(.top, 24)
        .frame(width: 760, height: 560)
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            settings.wallpaperID = appState.selectedWallpaperID
        }
        .fileImporter(isPresented: $isChoosingSong, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { settings.song = url }
        }
    }

    private var preview: some View {
        let size = settings.format.size
        return VStack(spacing: 12) {
            Color.black
                .aspectRatio(size.width / size.height, contentMode: .fit)
                .overlay {
                    if let wallpaper = WallpaperCatalog.wallpaper(id: settings.wallpaperID) {
                        wallpaper.makeView(WallpaperContext(source: SimulatedAudioSource.shared, isPaused: false, isPreview: true))
                            .id(wallpaper.id)
                    }
                }
                .overlay {
                    if settings.showsWatermark {
                        GeometryReader { ClipWatermark(unit: min($0.size.width, $0.size.height)) }
                    }
                }
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .frame(maxHeight: 440)
            Text("Preview moves to a demo beat. The clip follows your song.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Wallpaper", selection: $settings.wallpaperID) {
                    ForEach(WallpaperCatalog.collections) { collection in
                        Section(collection.name) {
                            ForEach(collection.wallpapers) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                Toggle("Shuffle through its collection every bar", isOn: $settings.shuffles)
            }
            Section {
                LabeledContent("Song") {
                    HStack {
                        Text(settings.song?.lastPathComponent ?? "None")
                            .foregroundStyle(settings.song == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { isChoosingSong = true }
                    }
                }
                Picker("Start", selection: $settings.startsAtHighlight) {
                    Text("Best part (loudest stretch)").tag(true)
                    Text("Beginning of the song").tag(false)
                }
                Picker("Length", selection: $settings.length) {
                    Text("15 s").tag(15.0)
                    Text("30 s").tag(30.0)
                    Text("60 s").tag(60.0)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker("Format", selection: $settings.format) {
                    ForEach(ClipSettings.Format.allCases) { format in
                        Text("\(format.title) · \(format.detail)").tag(format)
                    }
                }
                Toggle("Synced lyrics, when they can be found for the song", isOn: $settings.showsLyrics)
                Toggle("BeatsWall watermark", isOn: $settings.showsWatermark)
            }
        }
        .formStyle(.grouped)
        .disabled(exporter.isBusy)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            switch exporter.status {
            case .idle:
                Text("Use music you have the rights to post.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .analyzing:
                ProgressView().controlSize(.small)
                Text("Listening to the song…")
            case .rendering(let fraction):
                ProgressView(value: fraction)
                    .frame(width: 200)
                Text("Rendering \(Int(fraction * 100))%")
                    .monospacedDigit()
            case .finishing:
                ProgressView().controlSize(.small)
                Text("Adding the music…")
            case .done(let url):
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Saved \(url.lastPathComponent)").lineLimit(1)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).lineLimit(2)
            }
            Spacer()
            if exporter.isBusy {
                Button("Cancel", role: .cancel) { exporter.cancel() }
            } else {
                Button("Export Clip…", action: chooseDestination)
                    .keyboardShortcut(.defaultAction)
                    .disabled(settings.song == nil)
            }
        }
        .frame(minHeight: 28)
    }

    private func chooseDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        let name = WallpaperCatalog.wallpaper(id: settings.wallpaperID)?.name ?? "Clip"
        panel.nameFieldStringValue = "BeatsWall \(name).mp4"
        panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exporter.export(settings, to: url)
    }
}
