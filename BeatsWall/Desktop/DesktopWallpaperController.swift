//
//  DesktopWallpaperController.swift
//  BeatsWall
//

import AppKit
import SwiftUI

/// Puts a borderless, click-through window behind the desktop icons on every screen.
final class DesktopWallpaperController {
    private let appState: AppState
    private var windows: [NSWindow] = []
    private var observers: [NSObjectProtocol] = []
    private var coverTimer: Timer?

    init(appState: AppState) {
        self.appState = appState
        rebuildWindows()
        trackIconSetting()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let window = notification.object as? NSWindow, self.windows.contains(window) else { return }
                self.updateCovered()
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        let sleepEvents: [(Notification.Name, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.sessionDidResignActiveNotification, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, false),
        ]
        for (name, asleep) in sleepEvents {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appState.isSystemAsleep = asleep }
            })
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map(makeWindow)
    }

    private var windowLevel: NSWindow.Level {
        // Just above the icons hides them; normal windows still sit on top.
        if appState.hidesDesktopIcons {
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
        return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
    }

    private func trackIconSetting() {
        withObservationTracking {
            _ = appState.hidesDesktopIcons
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.windows.forEach { $0.level = self.windowLevel }
                self.trackIconSetting()
            }
        }
    }

    /// Pauses a moment after the desktop disappears (so flicking between spaces doesn't
    /// stutter), and resumes the instant it's back.
    private func updateCovered() {
        let covered = !windows.isEmpty && windows.allSatisfy { !$0.occlusionState.contains(.visible) }
        coverTimer?.invalidate()
        coverTimer = nil
        if covered {
            coverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.appState.isDesktopCovered = true }
            }
        } else {
            appState.isDesktopCovered = false
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = windowLevel
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .black

        let hostingView = NSHostingView(rootView: DesktopWallpaperView(displayID: screen.displayUUID).environment(appState))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(screen.frame, display: false)
        window.orderFront(nil)
        return window
    }
}

extension NSScreen {
    /// Stays the same for a display across launches and reconnects.
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

private struct DesktopWallpaperView: View {
    let displayID: String?
    @Environment(AppState.self) private var appState

    var body: some View {
        let wallpaper = appState.wallpaper(forDisplay: displayID)
        ZStack {
            wallpaper
                .makeView(WallpaperContext(source: appState.desktopSource, isPaused: !appState.isRendering, isPreview: false, frameRate: appState.frameRate))
                .id(wallpaper.id)
            if appState.showsLyrics {
                LyricsOverlay(lyrics: appState.lyrics, source: appState.desktopSource, isPaused: !appState.isRendering)
            }
        }
        .ignoresSafeArea()
    }
}
