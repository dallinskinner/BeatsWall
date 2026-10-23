//
//  LyricsOverlay.swift
//  BeatsWall
//

import SwiftUI

/// Karaoke-style lyrics over the wallpaper: the current line big in the center, filling in as
/// it's sung, with the next line faded below. Shows the song title briefly when a track starts.
struct LyricsOverlay: View {
    let lyrics: LyricsController
    let source: any AudioFeatureSource
    let isPaused: Bool

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: isPaused)) { timeline in
                let lyric = lyrics.lyric(at: timeline.date)
                let pulse = CGFloat(source.read().beatPulse)
                VStack(spacing: unit * 0.025) {
                    if let lyric {
                        currentLine(lyric.current.text, progress: lyric.progress, unit: unit)
                            .scaleEffect(1 + 0.025 * pulse)
                            .id(lyric.current.time)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: unit * 0.03)), removal: .opacity))
                        if let next = lyric.next, !next.text.isEmpty {
                            Text(next.text)
                                .font(.system(size: unit * 0.032, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .id(next.time)
                                .transition(.opacity)
                        }
                    } else if let track = lyrics.track, showsTitleCard(at: timeline.date) {
                        titleCard(track, unit: unit)
                            .transition(.opacity)
                    }
                }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.6), radius: unit * 0.01)
                .padding(.horizontal, unit * 0.05)
                .padding(.vertical, unit * 0.03)
                // A soft dark haze behind the words keeps them readable on light wallpapers too.
                .background {
                    if lyric != nil || lyrics.track != nil {
                        RoundedRectangle(cornerRadius: unit * 0.05)
                            .fill(.black.opacity(0.32))
                            .blur(radius: unit * 0.025)
                    }
                }
                .padding(.horizontal, unit * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.3), value: lyric?.current.time)
            }
        }
        .allowsHitTesting(false)
    }

    private func currentLine(_ text: String, progress: Double, unit: CGFloat) -> some View {
        // Instrumental gaps in LRC are empty lines; show a gentle note instead.
        let words = text.isEmpty ? "♪" : text
        // The sung part fills in bright white, left to right.
        let edge = min(max(progress, 0.001), 0.999)
        return Text(words)
            .font(.system(size: unit * 0.064, weight: .heavy, design: .rounded))
            .foregroundStyle(LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: edge),
                    .init(color: .white.opacity(0.62), location: min(edge + 0.02, 1)),
                    .init(color: .white.opacity(0.62), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            ))
    }

    private func titleCard(_ track: NowPlaying, unit: CGFloat) -> some View {
        VStack(spacing: unit * 0.01) {
            Text(track.title)
                .font(.system(size: unit * 0.045, weight: .heavy, design: .rounded))
            Text(track.artist)
                .font(.system(size: unit * 0.026, weight: .semibold, design: .rounded))
                .opacity(0.75)
        }
        .foregroundStyle(.white)
    }

    /// The title card shows for the first few seconds of a song, or while waiting for lyrics.
    private func showsTitleCard(at date: Date) -> Bool {
        if lyrics.status == .searching { return true }
        guard let position = lyrics.position(at: date) else { return false }
        return position < 6
    }
}
