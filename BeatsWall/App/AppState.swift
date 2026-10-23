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

    private static let wallpaperKey = "selectedWallpaperID"

    var selectedWallpaperID: String {
        didSet { UserDefaults.standard.set(selectedWallpaperID, forKey: Self.wallpaperKey) }
    }

    /// Paused from the menu bar or browser.
    var isPaused = false {
        didSet { updateAudio() }
    }

    /// Displays asleep or the user switched sessions.
    var isSystemAsleep = false {
        didSet { updateAudio() }
    }

    private(set) var audioStatus: AudioStatus = .stopped

    let liveAudio = AudioFeaturesStore()

    @ObservationIgnored private var tap: SystemAudioTap?
    @ObservationIgnored private var isStarted = false

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.wallpaperKey)
        if let saved, WallpaperCatalog.wallpaper(id: saved) != nil {
            selectedWallpaperID = saved
        } else {
            selectedWallpaperID = WallpaperCatalog.defaultWallpaperID
        }
    }

    var selectedWallpaper: Wallpaper {
        WallpaperCatalog.wallpaper(id: selectedWallpaperID) ?? WallpaperCatalog.wallpaper(id: WallpaperCatalog.defaultWallpaperID)!
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
        updateAudio()
    }

    func shutdown() {
        stopAudio()
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
