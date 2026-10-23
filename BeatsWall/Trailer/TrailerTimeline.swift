//
//  TrailerTimeline.swift
//  BeatsWall
//
//  Debug-only: what's on screen when in the trailer, with every cut on a bar line.
//

#if DEBUG
import Foundation

struct TrailerShot {
    enum Kind: Equatable {
        case intro
        case tour(collection: String)
        case shuffle
        case lyrics
        case endCard
    }

    var kind: Kind
    var wallpaperID: String
    /// Trailer time in seconds.
    var start: Double
    var end: Double
}

struct TrailerTimeline {
    static let length = 45.0

    /// One showcase wallpaper per collection, in catalog order.
    static let tour = [
        "claude.clawd", "skate.halfpipe", "synthwave.outrun-grid", "space.warp-drive", "nature.swell",
        "lofi.late-night-desk", "halloween.graveyard-rave", "arcade.star-shooter", "tokyo.ramen-alley",
        "winter.snow-globe", "deepsea.jellyfish-bloom", "minimal.breathing-rings", "cyber.hologram",
        "jungle.parrot-party", "desert.campfire",
    ]
    static let shufflePool = [
        "synthwave.neon-palms", "space.nebula", "cyber.code-rain", "skate.night-street", "deepsea.abyss-lure",
        "halloween.haunted-house", "jungle.canopy", "tokyo.midnight-train", "claude.spark-field", "arcade.maze-chase",
        "minimal.gradient-blobs", "desert.shooting-stars",
    ]

    let shots: [TrailerShot]

    /// Builds the cut list from the beats inside the trailer window (times relative to its start).
    init(beats: [Double]) {
        // Detection occasionally misses a beat, so cut on a steady grid at the song's median
        // tempo, anchored on the first beat (120 BPM if detection came up short).
        let intervals = zip(beats.dropFirst(), beats).map { $0 - $1 }.filter { $0 > 0.25 && $0 < 1.0 }.sorted()
        let beatLength = intervals.count > 8 ? intervals[intervals.count / 2] : 0.5
        let anchor = beats.first { $0 >= -0.01 } ?? 0
        let grid = stride(from: anchor, to: Self.length + 4, by: beatLength).map { $0 }
        let bars = stride(from: 0, to: grid.count, by: 4).map { grid[$0] }
        func bar(atOrAfter time: Double) -> Int { bars.firstIndex { $0 >= time - 0.05 } ?? bars.count - 1 }

        var shots: [TrailerShot] = []
        let introEnd = bars[bar(atOrAfter: 3.8)]
        shots.append(TrailerShot(kind: .intro, wallpaperID: "claude.spark-bloom", start: 0, end: introEnd))

        // Tour: one collection per bar.
        var barIndex = bar(atOrAfter: introEnd)
        for (index, id) in Self.tour.enumerated() where barIndex + 1 < bars.count {
            let collection = WallpaperCatalog.collections.first { $0.wallpapers.contains { $0.id == id } }?.name ?? ""
            shots.append(TrailerShot(kind: .tour(collection: collection), wallpaperID: id, start: bars[barIndex], end: bars[barIndex + 1]))
            barIndex += 1
            _ = index
        }

        // Shuffle demo: a new wallpaper on every beat for about six seconds.
        let shuffleStart = shots.last!.end
        let shuffleEnd = bars[bar(atOrAfter: shuffleStart + 5.5)]
        let beatsInShuffle = grid.filter { $0 >= shuffleStart - 0.01 && $0 < shuffleEnd - 0.01 }
        for (index, start) in beatsInShuffle.enumerated() {
            let end = index + 1 < beatsInShuffle.count ? beatsInShuffle[index + 1] : shuffleEnd
            shots.append(TrailerShot(kind: .shuffle, wallpaperID: Self.shufflePool[index % Self.shufflePool.count], start: start, end: end))
        }

        // Lyrics demo, then the end card.
        // Lyrics run until about three seconds from the end, leaving room for the end card.
        let lyricsEnd = max(min(bars[bar(atOrAfter: Self.length - 3.3)], Self.length - 2.5), shuffleEnd + 3)
        shots.append(TrailerShot(kind: .lyrics, wallpaperID: "tokyo.rainy-crossing", start: shuffleEnd, end: lyricsEnd))
        shots.append(TrailerShot(kind: .endCard, wallpaperID: "minimal.gradient-blobs", start: lyricsEnd, end: Self.length))
        self.shots = shots
    }

    func shot(at time: Double) -> (index: Int, shot: TrailerShot) {
        let index = shots.lastIndex { $0.start <= time } ?? 0
        return (index, shots[index])
    }
}
#endif
