//
//  Wallpaper.swift
//  BeatsWall
//

import SwiftUI

/// Everything a wallpaper view needs to render.
struct WallpaperContext {
    let source: any AudioFeatureSource
    let isPaused: Bool
    /// True for small thumbnails in the browser, so wallpapers can draw less.
    let isPreview: Bool
    /// When set, draw exactly this moment instead of following the display clock
    /// (used to render video offline).
    var renderTime: Double? = nil
    /// Frame rate cap for the desktop; previews always run at 30.
    var frameRate: Double = 60
}

struct Wallpaper: Identifiable {
    let id: String
    let name: String
    let summary: String
    let makeView: (WallpaperContext) -> AnyView

    init<Content: View>(
        id: String,
        name: String,
        summary: String,
        @ViewBuilder content: @escaping (WallpaperContext) -> Content
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        makeView = { AnyView(content($0)) }
    }
}

struct WallpaperCollection: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let symbol: String
    let accent: Color
    let wallpapers: [Wallpaper]
}

/// One frame's worth of input for a wallpaper.
struct AudioFrame {
    /// Seconds, wrapped daily so it stays precise enough for shaders.
    let time: Double
    let audio: AudioFeatures
}

/// Redraws its content every display frame with fresh audio features.
struct AudioTimeline<Content: View>: View {
    let context: WallpaperContext
    let content: (AudioFrame) -> Content

    init(context: WallpaperContext, @ViewBuilder content: @escaping (AudioFrame) -> Content) {
        self.context = context
        self.content = content
    }

    var body: some View {
        if let renderTime = context.renderTime {
            content(AudioFrame(time: renderTime, audio: context.source.read()))
        } else {
            TimelineView(.animation(minimumInterval: 1 / (context.isPreview ? 30 : context.frameRate), paused: context.isPaused)) { timeline in
                content(AudioFrame(
                    time: timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86_400),
                    audio: context.source.read()
                ))
            }
        }
    }
}
