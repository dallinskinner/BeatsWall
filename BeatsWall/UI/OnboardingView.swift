//
//  OnboardingView.swift
//  BeatsWall
//

import SwiftUI

/// First-run walkthrough: what BeatsWall is, the audio permission, a first collection, the
/// creator features, extras.
struct OnboardingView: View {
    static let completedKey = "hasCompletedOnboarding"

    private enum Step: Int, CaseIterable {
        case welcome, sound, collection, show, finish
    }

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @AppStorage(Self.completedKey) private var hasCompletedOnboarding = false
    @State private var step: Step
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled
    @AppStorage("creatorHandle") private var handle = ""

    /// `page` opens partway through, for previews.
    init(page: Int = 0) {
        _step = State(initialValue: Step(rawValue: page) ?? .welcome)
    }

    private static let audioSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .sound: sound
                case .collection: collection
                case .show: show
                case .finish: finish
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(32)

            Divider()
            HStack {
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.self) { item in
                        Circle()
                            .fill(item == step ? Color.accentColor : .secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step != .welcome {
                    Button("Back") { move(by: -1) }
                }
                Button(step == .finish ? "Start" : "Continue") {
                    if step == .finish {
                        hasCompletedOnboarding = true
                    } else {
                        move(by: 1)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 620, height: 520)
    }

    private func move(by offset: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            step = Step(rawValue: step.rawValue + offset) ?? step
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Color.black
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    appState.selectedWallpaper
                        .makeView(WallpaperContext(source: appState.desktopSource, isPaused: false, isPreview: true))
                }
                .clipShape(.rect(cornerRadius: 14))
                .frame(height: 230)
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                Text("Welcome to BeatsWall")
                    .font(.largeTitle.weight(.bold))
            }
            Text("Live wallpapers that dance to whatever's playing on your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Label("You're one of a few creators trying this early. Please don't share the app itself. Clips and posts are welcome!", systemImage: "sparkles")
                .font(.callout)
                .padding(10)
                .background(.tint.opacity(0.1), in: .rect(cornerRadius: 8))
        }
        .multilineTextAlignment(.center)
    }

    private var sound: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Let BeatsWall hear your music", systemImage: "waveform")
                .font(.title.weight(.bold))
            Text("BeatsWall listens to your Mac's sound output to find the beat, so it works with Spotify, Apple Music, YouTube or anything else.")
                .fixedSize(horizontal: false, vertical: true)
            Label("Audio is analyzed on your Mac as it plays. It's never recorded, saved or sent anywhere.", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
                let audio = appState.liveAudio.read()
                let hasSignal = appState.liveAudio.secondsSinceSignal < 2
                VStack(alignment: .leading, spacing: 10) {
                    switch appState.audioStatus {
                    case .failed(let message):
                        Label("Couldn't capture audio: \(message)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("Open Privacy Settings") { openURL(Self.audioSettings) }
                    case .listening where hasSignal:
                        Label("Hearing your music. Nice!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    default:
                        Label("Play a song to test it", systemImage: "music.note")
                        Text("If music is playing and the meter stays flat, allow BeatsWall under Privacy & Security › Screen & System Audio Recording.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Privacy Settings") { openURL(Self.audioSettings) }
                    }
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<AudioFeatures.binCount, id: \.self) { bin in
                            Capsule()
                                .fill(.tint)
                                .frame(width: 8, height: 4 + 56 * CGFloat(audio.spectrum[bin]))
                        }
                    }
                    .frame(height: 60, alignment: .bottom)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
            }
        }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Pick a starting collection", systemImage: "square.grid.2x2")
                .font(.title.weight(.bold))
            Text("You can switch anytime from the menu bar, or let shuffle pick for you.")
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(WallpaperCatalog.collections) { collection in
                        let isSelected = collection.wallpapers.contains { $0.id == appState.selectedWallpaperID }
                        Button {
                            if !isSelected, let first = collection.wallpapers.first {
                                appState.selectedWallpaperID = first.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: collection.symbol)
                                    .font(.title2)
                                    .foregroundStyle(collection.accent)
                                Text(collection.name)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(.background.secondary, in: .rect(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isSelected ? collection.accent : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var show: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 14) {
            Label("Make it a show", systemImage: "music.mic")
                .font(.title.weight(.bold))
            Form {
                Toggle(isOn: $appState.isConcertMode) {
                    Text("Concert Mode")
                    Text("A concert stage for whatever's playing in Music or Spotify, lit in its album art's colors with its name on the screens.")
                }
                LabeledContent("Stage image") {
                    HStack {
                        if let image = StageImage.shared.image {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 27)
                                .clipShape(.rect(cornerRadius: 3))
                        }
                        Button(StageImage.shared.image == nil ? "Choose…" : "Change…") { StageImage.shared.choose() }
                    }
                }
                TextField("Your handle", text: $handle, prompt: Text("@yourname"))
            }
            .formStyle(.grouped)
            Label("Record Clip… in the menu bar turns any wallpaper and song into a video for TikTok, Reels or Shorts, credited to your handle.", systemImage: "film")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("Show Mode (⌘F) plays the wallpaper full screen on a TV or second monitor, for filming your setup.", systemImage: "tv")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var finish: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 16) {
            Label("A few extras", systemImage: "slider.horizontal.3")
                .font(.title.weight(.bold))
            Form {
                Toggle("Open BeatsWall at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in
                        LaunchAtLogin.isEnabled = enabled
                        launchesAtLogin = LaunchAtLogin.isEnabled
                    }
                Toggle(isOn: $appState.showsLyrics) {
                    Text("Show synced lyrics")
                    Text("For songs playing in Apple Music or Spotify. macOS will ask to let BeatsWall see what's playing.")
                }
                Toggle(isOn: $appState.isShuffling) {
                    Text("Shuffle every bar")
                    Text("Switches wallpapers in time with the music.")
                }
            }
            .formStyle(.grouped)
        }
    }
}
