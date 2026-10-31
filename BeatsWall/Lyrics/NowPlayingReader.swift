//
//  NowPlayingReader.swift
//  BeatsWall
//

import AppKit
import Foundation

nonisolated struct NowPlaying: Sendable, Equatable {
    enum Player: String, Sendable {
        case music = "Apple Music"
        case spotify = "Spotify"
    }

    var player: Player
    var title: String
    var artist: String
    var album: String
    /// Seconds.
    var duration: Double
    /// Seconds into the track when this was read.
    var position: Double
    var isPlaying: Bool
    /// Apple Music's genre tag. Spotify doesn't share one.
    var genre = ""

    /// Identifies the song, ignoring playback position.
    var trackKey: String { "\(player.rawValue)|\(artist)|\(title)" }
}

nonisolated enum NowPlayingError: Error, Sendable {
    /// The user declined to let BeatsWall control the player (System Settings › Privacy › Automation).
    case notAuthorized(NowPlaying.Player)
}

/// Asks Music and Spotify what they're playing via AppleScript. Only talks to an app that is
/// already running, so it never launches one. Runs on its own serial queue.
nonisolated final class NowPlayingReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "julian.BeatsWall.now-playing", qos: .utility)

    nonisolated(unsafe) private static let musicScript = NSAppleScript(source: """
        tell application id "com.apple.Music"
            if player state is stopped then return {"stopped"}
            set t to current track
            return {player state as text, name of t, artist of t, album of t, duration of t, player position, genre of t}
        end tell
        """)
    nonisolated(unsafe) private static let musicArtworkScript = NSAppleScript(source: """
        tell application id "com.apple.Music"
            if (count of artworks of current track) is 0 then return ""
            return raw data of artwork 1 of current track
        end tell
        """)
    nonisolated(unsafe) private static let musicFileScript = NSAppleScript(source: """
        tell application id "com.apple.Music"
            if player state is stopped then return ""
            set t to current track
            if class of t is not file track then return ""
            return POSIX path of (location of t)
        end tell
        """)
    nonisolated(unsafe) private static let spotifyArtworkScript = NSAppleScript(source: """
        tell application id "com.spotify.client" to return artwork url of current track
        """)
    nonisolated(unsafe) private static let spotifyScript = NSAppleScript(source: """
        tell application id "com.spotify.client"
            if player state is stopped then return {"stopped"}
            set t to current track
            return {player state as text, name of t, artist of t, album of t, (duration of t) / 1000, player position}
        end tell
        """)

    func read(completion: @escaping @Sendable (Result<NowPlaying?, NowPlayingError>) -> Void) {
        queue.async {
            var paused: NowPlaying?
            for (player, bundleID, script) in [(NowPlaying.Player.music, "com.apple.Music", Self.musicScript), (.spotify, "com.spotify.client", Self.spotifyScript)] {
                guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty, let script else { continue }
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                if let error, (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                    completion(.failure(.notAuthorized(player)))
                    return
                }
                guard error == nil, let info = Self.parse(result, player: player) else { continue }
                // Prefer whichever app is actually playing.
                if info.isPlaying {
                    completion(.success(info))
                    return
                }
                paused = paused ?? info
            }
            completion(.success(paused))
        }
    }

    /// The audio file of the song Apple Music is playing, or nil when nothing is playing or it's
    /// streamed (Apple Music catalog and Spotify songs have no file to read).
    func musicFile() async -> URL? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let path = Self.musicFileScript?.executeAndReturnError(&error).stringValue ?? ""
                continuation.resume(returning: error == nil && !path.isEmpty ? URL(fileURLWithPath: path) : nil)
            }
        }
    }

    /// The current track's album art as image data: straight from Music, or downloaded from
    /// the URL Spotify gives.
    func artwork(from player: NowPlaying.Player) async -> Data? {
        let descriptor: NSAppleEventDescriptor? = await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let script = player == .music ? Self.musicArtworkScript : Self.spotifyArtworkScript
                let result = script?.executeAndReturnError(&error)
                continuation.resume(returning: error == nil ? result : nil)
            }
        }
        guard let descriptor else { return nil }
        switch player {
        case .music:
            let data = descriptor.data
            return data.isEmpty ? nil : data
        case .spotify:
            guard let string = descriptor.stringValue, let url = URL(string: string), url.scheme == "https" else { return nil }
            return try? await URLSession.shared.data(from: url).0
        }
    }

    private static func parse(_ descriptor: NSAppleEventDescriptor, player: NowPlaying.Player) -> NowPlaying? {
        guard descriptor.numberOfItems >= 6,
              let state = descriptor.atIndex(1)?.stringValue,
              let title = descriptor.atIndex(2)?.stringValue,
              let artist = descriptor.atIndex(3)?.stringValue else { return nil }
        return NowPlaying(
            player: player,
            title: title,
            artist: artist,
            album: descriptor.atIndex(4)?.stringValue ?? "",
            duration: descriptor.atIndex(5)?.doubleValue ?? 0,
            position: descriptor.atIndex(6)?.doubleValue ?? 0,
            isPlaying: state == "playing",
            genre: descriptor.numberOfItems >= 7 ? descriptor.atIndex(7)?.stringValue ?? "" : ""
        )
    }
}
