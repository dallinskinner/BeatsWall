//
//  TrailerView.swift
//  BeatsWall
//
//  Debug-only: one frame of the trailer, composited from real wallpapers and title overlays.
//

#if DEBUG
import AppKit
import SwiftUI

@Observable
final class TrailerModel {
    /// Trailer time in seconds.
    var time = 0.0
    let timeline: TrailerTimeline
    let source: OfflineAudioSource
    let lyrics: LyricsController
    /// Song time where the trailer starts.
    let songStart: Double
    /// Lyrics are timed against this date plus song time.
    let lyricsEpoch = Date(timeIntervalSinceReferenceDate: 0)

    init(timeline: TrailerTimeline, source: OfflineAudioSource, lyrics: LyricsController, songStart: Double) {
        self.timeline = timeline
        self.source = source
        self.lyrics = lyrics
        self.songStart = songStart
    }
}

struct TrailerView: View {
    let model: TrailerModel

    var body: some View {
        let time = model.time
        let (index, shot) = model.timeline.shot(at: time)
        let wallpaper = WallpaperCatalog.wallpaper(id: shot.wallpaperID)!
        let audio = model.source.read()

        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            ZStack {
                wallpaper
                    .makeView(WallpaperContext(source: model.source, isPaused: false, isPreview: false, renderTime: time))
                    .id(index)

                switch shot.kind {
                case .intro:
                    intro(time: time, shot: shot, unit: unit, pulse: Double(audio.beatPulse))
                case .tour(let collection):
                    chip(collection: collection, name: wallpaper.name, unit: unit, appear: time - shot.start)
                case .shuffle:
                    caption("Shuffle", detail: "A new wallpaper on every bar", symbol: "shuffle", unit: unit)
                case .lyrics:
                    LyricsOverlay(
                        lyrics: model.lyrics, source: model.source, isPaused: false,
                        fixedDate: model.lyricsEpoch.addingTimeInterval(model.songStart + time)
                    )
                    caption("Live synced lyrics", detail: "For whatever's playing in Music or Spotify", symbol: "quote.bubble", unit: unit)
                case .endCard:
                    endCard(time: time, shot: shot, unit: unit, pulse: Double(audio.beatPulse))
                }

                // Fade up from black at the start and down to black at the end.
                Color.black.opacity(max(1 - time / 0.5, max(0, (time - (TrailerTimeline.length - 1)) / 1)))
            }
        }
    }

    private var icon: Image {
        Image(nsImage: NSApp.applicationIconImage)
    }

    private func intro(time: Double, shot: TrailerShot, unit: CGFloat, pulse: Double) -> some View {
        let appear = smoothstep(0.3, 1.2, time)
        let tagline = smoothstep(1.6, 2.4, time)
        return ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: unit * 0.03) {
                HStack(spacing: unit * 0.035) {
                    icon.resizable().frame(width: unit * 0.17, height: unit * 0.17)
                    Text("BeatsWall")
                        .font(.system(size: unit * 0.13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect((0.85 + 0.15 * appear) * (1 + 0.03 * pulse))
                .opacity(appear)
                Text("Your wallpaper, dancing to your music.")
                    .font(.system(size: unit * 0.045, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(tagline)
                    .offset(y: unit * 0.02 * (1 - tagline))
            }
            .shadow(color: .black.opacity(0.5), radius: unit * 0.02)
        }
    }

    private func chip(collection: String, name: String, unit: CGFloat, appear: Double) -> some View {
        let accent = WallpaperCatalog.collections.first { $0.name == collection }?.accent ?? .white
        let slide = smoothstep(0, 0.25, appear)
        return VStack {
            Spacer()
            HStack {
                HStack(spacing: unit * 0.015) {
                    Circle().fill(accent).frame(width: unit * 0.018, height: unit * 0.018)
                    Text(collection)
                        .font(.system(size: unit * 0.032, weight: .heavy, design: .rounded))
                    Text(name)
                        .font(.system(size: unit * 0.032, weight: .medium, design: .rounded))
                        .opacity(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, unit * 0.03)
                .padding(.vertical, unit * 0.016)
                .background(.black.opacity(0.45), in: Capsule())
                .offset(x: -unit * 0.05 * (1 - slide))
                .opacity(slide)
                Spacer()
            }
            .padding(unit * 0.06)
        }
    }

    private func caption(_ title: String, detail: String, symbol: String, unit: CGFloat) -> some View {
        VStack {
            HStack(spacing: unit * 0.018) {
                Image(systemName: symbol)
                    .font(.system(size: unit * 0.036, weight: .bold))
                VStack(alignment: .leading, spacing: unit * 0.004) {
                    Text(title).font(.system(size: unit * 0.038, weight: .heavy, design: .rounded))
                    Text(detail).font(.system(size: unit * 0.024, weight: .medium, design: .rounded)).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, unit * 0.035)
            .padding(.vertical, unit * 0.02)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: unit * 0.03))
            .padding(.top, unit * 0.06)
            Spacer()
        }
    }

    private func endCard(time: Double, shot: TrailerShot, unit: CGFloat, pulse: Double) -> some View {
        let appear = smoothstep(shot.start, shot.start + 0.6, time)
        let wallpaperCount = WallpaperCatalog.collections.reduce(0) { $0 + $1.wallpapers.count }
        return ZStack {
            Color.black.opacity(0.2)
            VStack(spacing: unit * 0.025) {
                icon.resizable().frame(width: unit * 0.22, height: unit * 0.22)
                    .scaleEffect(1 + 0.04 * pulse)
                Text("BeatsWall")
                    .font(.system(size: unit * 0.11, weight: .heavy, design: .rounded))
                Text("\(WallpaperCatalog.collections.count) collections · \(wallpaperCount) live wallpapers · for macOS")
                    .font(.system(size: unit * 0.032, weight: .semibold, design: .rounded))
                    .opacity(0.8)
            }
            .foregroundStyle(MinimalTheme.ink)
            .opacity(appear)
            .scaleEffect(0.94 + 0.06 * appear)
        }
    }
}
#endif
