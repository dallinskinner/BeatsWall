//
//  ConcertControls.swift
//  BeatsWall
//
//  Concert Mode's stage choice and the lighting desk, shared by the menu bar and Settings.
//

import AppKit
import SwiftUI

/// Automatic, Shuffle, or one stage from the Concert or Light Show collection.
struct ConcertStagePicker: View {
    @Bindable var appState: AppState

    var body: some View {
        Picker("Stage", selection: $appState.concertStageID) {
            Text("Automatic").tag(String?.none)
            Text("Shuffle").tag(String?.some(ConcertShow.shuffleID))
            Section("Concert") {
                ForEach(ConcertShow.concertStages, id: \.self) { stage($0) }
            }
            Section("Light Show") {
                ForEach(ConcertShow.lightShowStages, id: \.self) { stage($0) }
            }
        }
    }

    private func stage(_ id: String) -> some View {
        Text(WallpaperCatalog.wallpaper(id: id)?.name ?? id).tag(String?.some(id))
    }
}

struct ConcertShufflePicker: View {
    @Bindable var appState: AppState

    var body: some View {
        Picker("Shuffle From", selection: $appState.concertShufflePool) {
            ForEach(ConcertShow.ShufflePool.allCases) { Text($0.title).tag($0) }
        }
    }
}

/// The lighting desk's pickers: colors, lasers, strobe and movement.
struct LightingPickers: View {
    @Bindable var appState: AppState

    var body: some View {
        Picker("Colors", selection: $appState.lightRig.colors) {
            ForEach(LightRig.Colors.allCases) { Text($0.title).tag($0) }
        }
        Picker("Lasers", selection: $appState.lightRig.pattern) {
            ForEach(LightRig.Pattern.allCases) { Text($0.title).tag($0) }
        }
        Picker("Strobe", selection: $appState.lightRig.strobe) {
            ForEach(LightRig.Strobe.allCases) { Text($0.title).tag($0) }
        }
        Picker("Movement", selection: $appState.lightRig.movement) {
            ForEach(LightRig.Movement.allCases) { Text($0.title).tag($0) }
        }
    }
}

/// The lighting desk in Settings: the pickers plus a custom color and sliders.
struct LightingSettings: View {
    @Bindable var appState: AppState

    var body: some View {
        LightingPickers(appState: appState)
        if appState.lightRig.colors == .custom {
            ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
        }
        slider("Intensity", value: $appState.lightRig.intensity, in: 0.5...1.5)
        slider("Fog", value: $appState.lightRig.fog, in: 0...1)
        slider("Speed", value: $appState.lightRig.speed, in: 0.5...2)
        HStack {
            Text("Applies to the Concert and Light Show collections, and to recorded clips.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { appState.lightRig = .standard }
                .disabled(appState.lightRig == .standard)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range)
                .frame(maxWidth: 220)
        }
    }

    /// The rig keeps its custom color as 0xRRGGBB.
    private var customColor: Binding<Color> {
        Binding {
            Color(hex: appState.lightRig.customColor)
        } set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
            appState.lightRig.customColor = channel(rgb.redComponent) << 16 | channel(rgb.greenComponent) << 8 | channel(rgb.blueComponent)
        }
    }
}
