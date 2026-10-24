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

        Window("Record Clip", id: "clip") {
            ClipExportView()
                .environment(appDelegate.appState)
        }
        .windowResizability(.contentSize)

        Window("Send Feedback", id: "feedback") {
            FeedbackView()
                .environment(appDelegate.appState)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }

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
        if BetaInfo.hasExpired {
            BetaInfo.showExpiredAndQuit()
            return
        }
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
