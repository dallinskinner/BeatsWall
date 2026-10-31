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
    private static let concertKey = "isConcertMode"
    private static let reactivityKey = "reactivity"
    private static let frameRateKey = "frameRate"
    private static let pausesWhenCoveredKey = "pausesWhenCovered"
    private static let pausesInLowPowerKey = "pausesInLowPower"
    private static let hidesDesktopIconsKey = "hidesDesktopIcons"
    private static let displayWallpapersKey = "displayWallpaperIDs"

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

    /// Puts on a show for the playing song: a Concert stage that suits it, in its album art's
    /// colors, with its name on the screens. Takes over from shuffle while it's on.
    var isConcertMode: Bool {
        didSet {
            UserDefaults.standard.set(isConcertMode, forKey: Self.concertKey)
            updateConcert()
            updateShuffle()
        }
    }

    let concert = ConcertShow()

    /// How strongly wallpapers react: 1 is as analyzed, up to 2x for quiet setups.
    var reactivity: Double {
        didSet {
            UserDefaults.standard.set(reactivity, forKey: Self.reactivityKey)
            liveAudio.gain = Float(reactivity)
        }
    }

    /// Desktop frame rate cap.
    var frameRate: Double {
        didSet { UserDefaults.standard.set(frameRate, forKey: Self.frameRateKey) }
    }

    var pausesWhenCovered: Bool {
        didSet {
            UserDefaults.standard.set(pausesWhenCovered, forKey: Self.pausesWhenCoveredKey)
            updateRunning()
        }
    }

    var pausesInLowPower: Bool {
        didSet {
            UserDefaults.standard.set(pausesInLowPower, forKey: Self.pausesInLowPowerKey)
            updateRunning()
        }
    }

    /// Lift the wallpaper above the desktop icons, for clean screen recordings.
    var hidesDesktopIcons: Bool {
        didSet { UserDefaults.standard.set(hidesDesktopIcons, forKey: Self.hidesDesktopIconsKey) }
    }

    /// Wallpapers pinned to particular displays, by display UUID. Displays without one
    /// show the main selection (and follow shuffle).
    var displayWallpaperIDs: [String: String] {
        didSet { UserDefaults.standard.set(displayWallpaperIDs, forKey: Self.displayWallpapersKey) }
    }

    /// Paused from the menu bar or browser.
    var isPaused = false {
        didSet { updateRunning() }
    }

    /// Displays asleep or the user switched sessions.
    var isSystemAsleep = false {
        didSet { updateRunning() }
    }

    /// Every wallpaper window is hidden behind other windows or in a full-screen space.
    var isDesktopCovered = false {
        didSet { updateRunning() }
    }

    private(set) var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled {
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
        isConcertMode = defaults.bool(forKey: Self.concertKey)
        defaults.register(defaults: [
            Self.reactivityKey: 1.0,
            Self.frameRateKey: 60.0,
            Self.pausesWhenCoveredKey: true,
            Self.pausesInLowPowerKey: true,
        ])
        reactivity = defaults.double(forKey: Self.reactivityKey)
        frameRate = defaults.double(forKey: Self.frameRateKey)
        pausesWhenCovered = defaults.bool(forKey: Self.pausesWhenCoveredKey)
        pausesInLowPower = defaults.bool(forKey: Self.pausesInLowPowerKey)
        hidesDesktopIcons = defaults.bool(forKey: Self.hidesDesktopIconsKey)
        displayWallpaperIDs = defaults.dictionary(forKey: Self.displayWallpapersKey) as? [String: String] ?? [:]
        liveAudio.gain = Float(reactivity)
    }

    var selectedWallpaper: Wallpaper {
        WallpaperCatalog.wallpaper(id: selectedWallpaperID) ?? WallpaperCatalog.wallpaper(id: WallpaperCatalog.defaultWallpaperID)!
    }

    /// What's on the desktop right now: Concert Mode's stage, the shuffle pick, or the selection.
    var displayedWallpaper: Wallpaper {
        if isConcertMode, let stage = WallpaperCatalog.wallpaper(id: concert.stageID) { return stage }
        return shuffledWallpaperID.flatMap { WallpaperCatalog.wallpaper(id: $0) } ?? selectedWallpaper
    }

    /// The wallpaper for one display: its pinned wallpaper, or whatever's on the main desktop.
    func wallpaper(forDisplay displayID: String?) -> Wallpaper {
        displayID.flatMap { displayWallpaperIDs[$0] }.flatMap { WallpaperCatalog.wallpaper(id: $0) } ?? displayedWallpaper
    }

    var isRendering: Bool {
        !isPaused && !isSystemAsleep
            && !(pausesWhenCovered && isDesktopCovered)
            && !(pausesInLowPower && isLowPower)
    }

    /// Why the wallpaper is still, if it is.
    var pauseReason: String? {
        if isPaused { return "Paused" }
        if isSystemAsleep { return "Paused while the display sleeps" }
        if pausesWhenCovered && isDesktopCovered { return "Paused while the desktop is covered" }
        if pausesInLowPower && isLowPower { return "Paused in Low Power Mode" }
        return nil
    }

    /// Live audio when we can capture it, otherwise a demo beat so the desktop still moves.
    var desktopSource: any AudioFeatureSource {
        if case .failed = audioStatus { return SimulatedAudioSource.shared }
        return liveAudio
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeOutputDeviceChanges()
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
        updateRunning()
    }

    func shutdown() {
        stopAudio()
        lyrics.setActive(false)
        concert.setActive(false, lyrics: lyrics) { AudioFeatures() }
        shuffleTimer?.invalidate()
    }

    private func updateRunning() {
        updateAudio()
        updateShuffle()
        updateLyrics()
        updateConcert()
    }

    private func updateConcert() {
        guard isStarted else { return }
        concert.setActive(isConcertMode && isRendering, lyrics: lyrics) { [weak self] in
            self?.desktopSource.read() ?? AudioFeatures()
        }
    }

    private func updateLyrics() {
        guard isStarted else { return }
        lyrics.setActive(showsLyrics && isRendering)
    }

    // MARK: - Shuffle

    /// Watches for beats ~30 times a second while shuffling and switches on each bar's downbeat.
    private func updateShuffle() {
        let shouldRun = isStarted && isShuffling && !isConcertMode && isRendering
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
