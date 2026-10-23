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

    init(appState: AppState) {
        self.appState = appState
        rebuildWindows()

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

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .black

        let hostingView = NSHostingView(rootView: DesktopWallpaperView().environment(appState))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(screen.frame, display: false)
        window.orderFront(nil)
        return window
    }
}

private struct DesktopWallpaperView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        appState.selectedWallpaper
            .makeView(WallpaperContext(source: appState.desktopSource, isPaused: !appState.isRendering, isPreview: false))
            .id(appState.selectedWallpaperID)
            .ignoresSafeArea()
    }
}
