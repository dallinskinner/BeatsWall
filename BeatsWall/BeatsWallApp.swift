//
//  BeatsWallApp.swift
//  BeatsWall
//
//  Created by Julian Skinner on 10/23/26.
//

import SwiftUI

@main
struct BeatsWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("BeatsWall", id: "collections") {
            CollectionsView()
                .environment(appDelegate.appState)
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.appState)
        } label: {
            Image(nsImage: BeatsWallLogo.menuBarImage)
                .accessibilityLabel("BeatsWall")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var desktop: DesktopWallpaperController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if TrailerRenderer.runIfRequested() { return }
        #endif
        desktop = DesktopWallpaperController(appState: appState)
        appState.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdown()
    }
}
