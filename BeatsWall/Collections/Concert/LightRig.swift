//
//  LightRig.swift
//  BeatsWall
//
//  The user's lighting desk for the Concert and Light Show collections: colors, laser patterns,
//  strobe, intensity, fog and how the fixtures move. The defaults are the stages' own look.
//

import AppKit
import SwiftUI

struct LightRig: Codable, Equatable {
    enum Colors: String, Codable, CaseIterable, Identifiable {
        case auto, ice, sunset, toxic, rainbow, mono, custom

        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: "Automatic"
            case .ice: "Ice"
            case .sunset: "Sunset"
            case .toxic: "Toxic"
            case .rainbow: "Rainbow"
            case .mono: "White"
            case .custom: "Custom"
            }
        }
    }

    enum Pattern: String, Codable, CaseIterable, Identifiable {
        case auto, fan, tunnel, sheet, cone, crossfire

        var id: String { rawValue }
        var title: String {
            switch self {
            case .auto: "Automatic"
            case .fan: "Fan"
            case .tunnel: "Tunnel"
            case .sheet: "Sheet"
            case .cone: "Cone"
            case .crossfire: "Crossfire"
            }
        }
    }

    enum Strobe: String, Codable, CaseIterable, Identifiable {
        case off, soft, full

        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: "Off"
            case .soft: "Soft"
            case .full: "Full"
            }
        }
        var amount: Double {
            switch self {
            case .off: 0
            case .soft: 0.35
            case .full: 1
            }
        }
    }

    enum Movement: String, Codable, CaseIterable, Identifiable {
        case sweep, chase, pulse, still

        var id: String { rawValue }
        var title: String {
            switch self {
            case .sweep: "Sweep"
            case .chase: "Chase"
            case .pulse: "Pulse"
            case .still: "Still"
            }
        }
    }

    var colors = Colors.auto
    /// The color for `.custom`, as 0xRRGGBB.
    var customColor: UInt32 = 0xFF2E88
    var pattern = Pattern.auto
    var strobe = Strobe.full
    /// Beam and laser brightness, 0.5...1.5.
    var intensity = 1.0
    /// How much haze the beams light up, 0...1.
    var fog = 0.5
    var movement = Movement.sweep
    /// How fast fixtures move, 0.5...2.
    var speed = 1.0

    /// The out-of-the-box rig, with a gentler strobe for people who've asked macOS to reduce motion.
    static var standard: LightRig {
        var rig = LightRig()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { rig.strobe = .soft }
        return rig
    }

    /// The colors this rig forces, or nil to let the song, stage image or stage decide.
    var palette: [Color]? {
        switch colors {
        case .auto:
            return nil
        case .ice:
            return [Color(hex: 0x6FD3FF), Color(hex: 0xBFEFFF), Color(hex: 0x4A7BFF), .white]
        case .sunset:
            return [Color(hex: 0xFF5E3A), Color(hex: 0xFFB23F), Color(hex: 0xFF2E88), Color(hex: 0xFFD9A0)]
        case .toxic:
            return [Color(hex: 0x39FF6A), Color(hex: 0xC6FF3A), Color(hex: 0x00E5A0), Color(hex: 0x9DFF8A)]
        case .rainbow:
            return [0.0, 0.08, 0.16, 0.33, 0.5, 0.62, 0.78, 0.9].map { Color(hue: $0, saturation: 0.8, brightness: 1) }
        case .mono:
            return [.white, Color(hex: 0xE8ECFF), Color(hex: 0xFFF4E0)]
        case .custom:
            let base = Color(hex: customColor)
            return [base, base.mix(with: .white, by: 0.35), base.mix(with: .white, by: 0.65)]
        }
    }
}

extension LightRig {
    /// Stored in UserDefaults as JSON.
    static func load(from defaults: UserDefaults, key: String) -> LightRig {
        guard let data = defaults.data(forKey: key), let rig = try? JSONDecoder().decode(LightRig.self, from: data) else { return .standard }
        return rig
    }

    func save(to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: key) }
    }
}
