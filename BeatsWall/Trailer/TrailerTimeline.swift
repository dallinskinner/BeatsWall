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
        "beatswall.woofie", "concert.main-stage", "skate.halfpipe", "synthwave.outrun-grid", "space.warp-drive", "nature.swell",
        "lofi.late-night-desk", "halloween.graveyard-rave", "arcade.star-shooter", "tokyo.ramen-alley",
        "winter.snow-globe", "deepsea.jellyfish-bloom", "minimal.breathing-rings", "cyber.hologram",
        "jungle.parrot-party", "desert.campfire",
    ]
    static let shufflePool = [
        "synthwave.neon-palms", "space.nebula", "cyber.code-rain", "skate.night-street", "deepsea.abyss-lure",
        "halloween.haunted-house", "jungle.canopy", "tokyo.midnight-train", "beatswall.beat-b", "arcade.maze-chase",
        "minimal.gradient-blobs", "desert.shooting-stars",
    ]

    let shots: [TrailerShot]

    /// Builds the cut list from the beats inside the trailer window (times relative to its start).
    init(beats: [Double]) {
        let beatGrid = BeatGrid(detectedBeats: beats, length: Self.length)
        let grid = beatGrid.beats
        let bars = beatGrid.bars
        func bar(atOrAfter time: Double) -> Int { beatGrid.bar(atOrAfter: time) }

        var shots: [TrailerShot] = []
        let introEnd = bars[bar(atOrAfter: 3.8)]
        shots.append(TrailerShot(kind: .intro, wallpaperID: "beatswall.spark-field", start: 0, end: introEnd))

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
