//
//  AppState.swift
//  BeatsWall
//

import CoreAudio
import Foundation
import Observation

@Observable
final class AppState {
    enum AudioStatus: Equatable {
        case stopped
        case listening
        case failed(String)
    }

    enum ShufflePool: String, CaseIterable, Identifiable {
        case collection
        case everything

        var id: String { rawValue }
        var title: String {
            switch self {
            case .collection: "This Collection"
            case .everything: "All Wallpapers"
            }
        }
    }

    private static let wallpaperKey = "selectedWallpaperID"
    private static let shuffleKey = "isShuffling"
    private static let shufflePoolKey = "shufflePool"
    private static let lyricsKey = "showsLyrics"

    var selectedWallpaperID: String {
        didSet {
            UserDefaults.standard.set(selectedWallpaperID, forKey: Self.wallpaperKey)
            // Picking a wallpaper shows it right away; shuffle carries on from the next bar.
            shuffledWallpaperID = nil
        }
    }

    /// Switch to a random wallpaper on the downbeat of every bar.
    var isShuffling: Bool {
        didSet {
            UserDefaults.standard.set(isShuffling, forKey: Self.shuffleKey)
            if !isShuffling { shuffledWallpaperID = nil }
            updateShuffle()
        }
    }

    var shufflePool: ShufflePool {
        didSet { UserDefaults.standard.set(shufflePool.rawValue, forKey: Self.shufflePoolKey) }
    }

    /// The wallpaper shuffle is currently showing, if it has moved away from the selection.
    private(set) var shuffledWallpaperID: String?

    var showsLyrics: Bool {
        didSet {
            UserDefaults.standard.set(showsLyrics, forKey: Self.lyricsKey)
            updateLyrics()
        }
    }

    let lyrics = LyricsController()

    /// Paused from the menu bar or browser.
    var isPaused = false {
        didSet { updateRunning() }
    }

    /// Displays asleep or the user switched sessions.
    var isSystemAsleep = false {
        didSet { updateRunning() }
    }

    private(set) var audioStatus: AudioStatus = .stopped

    let liveAudio = AudioFeaturesStore()

    @ObservationIgnored private var tap: SystemAudioTap?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var shuffleTimer: Timer?
    @ObservationIgnored private var shuffleBeat = BeatEdge()

    init() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: Self.wallpaperKey)
        if let saved, WallpaperCatalog.wallpaper(id: saved) != nil {
            selectedWallpaperID = saved
        } else {
            selectedWallpaperID = WallpaperCatalog.defaultWallpaperID
        }
        isShuffling = defaults.bool(forKey: Self.shuffleKey)
        shufflePool = defaults.string(forKey: Self.shufflePoolKey).flatMap(ShufflePool.init(rawValue:)) ?? .collection
        showsLyrics = defaults.bool(forKey: Self.lyricsKey)
    }

    var selectedWallpaper: Wallpaper {
        WallpaperCatalog.wallpaper(id: selectedWallpaperID) ?? WallpaperCatalog.wallpaper(id: WallpaperCatalog.defaultWallpaperID)!
    }

    /// What's on the desktop right now: the shuffle pick, or the selection.
    var displayedWallpaper: Wallpaper {
        shuffledWallpaperID.flatMap { WallpaperCatalog.wallpaper(id: $0) } ?? selectedWallpaper
    }

    var isRendering: Bool { !isPaused && !isSystemAsleep }

    /// Live audio when we can capture it, otherwise a demo beat so the desktop still moves.
    var desktopSource: any AudioFeatureSource {
        if case .failed = audioStatus { return SimulatedAudioSource.shared }
        return liveAudio
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeOutputDeviceChanges()
        updateRunning()
    }

    func shutdown() {
        stopAudio()
        lyrics.setActive(false)
        shuffleTimer?.invalidate()
    }

    private func updateRunning() {
        updateAudio()
        updateShuffle()
        updateLyrics()
    }

    private func updateLyrics() {
        guard isStarted else { return }
        lyrics.setActive(showsLyrics && isRendering)
    }

    // MARK: - Shuffle

    /// Watches for beats ~30 times a second while shuffling and switches on each bar's downbeat.
    private func updateShuffle() {
        let shouldRun = isStarted && isShuffling && isRendering
        if shouldRun, shuffleTimer == nil {
            shuffleBeat = BeatEdge()
            shuffleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkShuffleBeat() }
            }
        } else if !shouldRun {
            shuffleTimer?.invalidate()
            shuffleTimer = nil
        }
    }

    private func checkShuffleBeat() {
        let audio = desktopSource.read()
        guard shuffleBeat.isNewBeat(audio), audio.beatCount % 4 == 0 else { return }
        let pool: [Wallpaper]
        switch shufflePool {
        case .everything:
            pool = WallpaperCatalog.collections.flatMap(\.wallpapers)
        case .collection:
            pool = WallpaperCatalog.collections.first { $0.wallpapers.contains { $0.id == selectedWallpaperID } }?.wallpapers ?? []
        }
        let current = displayedWallpaper.id
        if let next = pool.filter({ $0.id != current }).randomElement() {
            shuffledWallpaperID = next.id
        }
    }

    private func updateAudio() {
        guard isStarted else { return }
        if isRendering { startAudio() } else { stopAudio() }
    }

    private func startAudio() {
        guard tap == nil else { return }
        let tap = SystemAudioTap(analyzer: AudioAnalyzer(store: liveAudio))
        do {
            try tap.start()
            self.tap = tap
            audioStatus = .listening
        } catch {
            audioStatus = .failed(error.localizedDescription)
        }
    }

    private func stopAudio() {
        tap?.stop()
        tap = nil
        if audioStatus == .listening { audioStatus = .stopped }
    }

    /// The tap is bound to the output device, so rebuild it when the user switches
    /// speakers or connects headphones.
    private func observeOutputDeviceChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, self.tap != nil else { return }
                self.stopAudio()
                self.updateAudio()
            }
        }
    }
}
