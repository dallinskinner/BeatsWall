//
//  SettingsView.swift
//  BeatsWall
//

import ServiceManagement
import SwiftUI

enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("BeatsWall: couldn't change launch at login: \(error)")
            }
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled
    @State private var screens = NSScreen.screens

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("General") {
                Toggle("Open BeatsWall at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in
                        LaunchAtLogin.isEnabled = enabled
                        launchesAtLogin = LaunchAtLogin.isEnabled
                    }
                Toggle("Hide desktop icons", isOn: $appState.hidesDesktopIcons)
                Text("Handy for clean screen recordings. Your files are still in Finder's Desktop folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Show Welcome Again…") { hasCompletedOnboarding = false }
            }

            Section("Music") {
                LabeledContent("Reactivity") {
                    HStack {
                        Slider(value: $appState.reactivity, in: 0.5...2, step: 0.1) {
                            EmptyView()
                        } minimumValueLabel: {
                            Image(systemName: "speaker.wave.1")
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3")
                        }
                        Text("\(Int((appState.reactivity * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text("Turn it up if wallpapers barely move at your listening volume.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Performance") {
                Picker("Frame rate", selection: $appState.frameRate) {
                    Text("Smooth · 60 fps").tag(60.0)
                    Text("Light · 30 fps").tag(30.0)
                }
                Toggle("Pause when windows cover the desktop", isOn: $appState.pausesWhenCovered)
                Toggle("Pause in Low Power Mode", isOn: $appState.pausesInLowPower)
                if let reason = appState.pauseReason {
                    Label(reason, systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }
            }

            if screens.count > 1 {
                Section("Displays") {
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        if let displayID = screen.displayUUID {
                            Picker(screen.localizedName, selection: displayBinding(displayID)) {
                                Text(index == 0 ? "Main wallpaper" : "Same as main").tag(String?.none)
                                ForEach(WallpaperCatalog.collections) { collection in
                                    Section(collection.name) {
                                        ForEach(collection.wallpapers) { Text($0.name).tag(String?.some($0.id)) }
                                    }
                                }
                            }
                        }
                    }
                    Text("Displays set to \"Same as main\" follow your selection and shuffle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Version", value: BetaInfo.versionDescription)
                if let expiresAt = BetaInfo.expiresAt {
                    LabeledContent("Beta ends", value: expiresAt.addingTimeInterval(-1).formatted(date: .long, time: .omitted))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private func displayBinding(_ displayID: String) -> Binding<String?> {
        Binding {
            appState.displayWallpaperIDs[displayID]
        } set: {
            appState.displayWallpaperIDs[displayID] = $0
        }
    }
}
