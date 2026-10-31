//
//  ShowModeController.swift
//  BeatsWall
//
//  Show Mode: the wallpaper full screen above everything, for a TV, projector or second
//  monitor while filming a setup. Esc leaves.
//

import AppKit
import SwiftUI

final class ShowModeController {
    /// Set up by the app delegate, so the menu can reach it.
    static var shared: ShowModeController?

    private let appState: AppState
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var cursorTimer: Timer?
    private var lastMouse = NSPoint.zero
    private var stillFor = 0.0

    init(appState: AppState) {
        self.appState = appState
    }

    func toggle() {
        if window == nil {
            open(on: NSScreen.main ?? NSScreen.screens[0])
        } else {
            close()
        }
    }

    func open(on screen: NSScreen) {
        close()
        let window = ShowWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        // Above the menu bar and Dock, so nothing but the show is on that screen.
        window.level = .screenSaver
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: ShowModeView().environment(appState))
        window.setFrame(screen.frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        self.window = window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.close()
            return nil
        }
        // Hide the pointer once it's been still for two seconds.
        lastMouse = NSEvent.mouseLocation
        stillFor = 0
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkCursor() }
        }
        appState.isShowing = true
    }

    func close() {
        guard let window else { return }
        window.orderOut(nil)
        self.window = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        cursorTimer?.invalidate()
        cursorTimer = nil
        appState.isShowing = false
    }

    private func checkCursor() {
        let mouse = NSEvent.mouseLocation
        if mouse != lastMouse {
            lastMouse = mouse
            stillFor = 0
            return
        }
        stillFor += 0.5
        if stillFor == 2 { NSCursor.setHiddenUntilMouseMoves(true) }
    }
}

/// Borderless windows can't take key focus by default, and Show Mode needs it for Esc.
private final class ShowWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private struct ShowModeView: View {
    @Environment(AppState.self) private var appState
    @State private var showsHint = true

    var body: some View {
        WallpaperStage(wallpaper: appState.displayedWallpaper, isPaused: !appState.isShowRendering)
            .overlay(alignment: .bottom) {
                if showsHint {
                    Text("Press Esc to leave Show Mode")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.6)) { showsHint = false }
            }
    }
}
