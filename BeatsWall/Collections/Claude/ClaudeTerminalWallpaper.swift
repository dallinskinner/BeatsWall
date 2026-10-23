//
//  ClaudeTerminalWallpaper.swift
//  BeatsWall
//

import SwiftUI

struct ClaudeTerminalWallpaper: View {
    let context: WallpaperContext

    private static let spinner = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
    private static let verbs = ["Vibing", "Grooving", "Syncopating", "Riffing", "Harmonizing", "Pondering", "Jamming", "Noodling", "Swaying", "Composing"]
    private static let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    private static let spectrumRows = 10

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let fontSize = min(size.width / 70, size.height / 30)

            AudioTimeline(context: context) { frame in
                ZStack {
                    RadialGradient(
                        colors: [ClaudeTheme.warmDark, ClaudeTheme.ink],
                        center: .center, startRadius: 0, endRadius: max(size.width, size.height) * 0.7
                    )
                    terminal(frame: frame, fontSize: fontSize)
                        .shadow(color: ClaudeTheme.terracotta.opacity(0.25 + 0.3 * Double(frame.audio.beatPulse)), radius: fontSize * 0.8)
                }
                .frame(width: size.width, height: size.height)
                .colorEffect(ShaderLibrary.claudeScanlines(.float(frame.time), .float(0.16), .float(max(2, fontSize / 6))))
            }
        }
    }

    private func terminal(frame: AudioFrame, fontSize: CGFloat) -> some View {
        let audio = frame.audio
        let dim = ClaudeTheme.cream.opacity(0.45)
        // The spinner advances a frame per beat, plus a slow idle tick so it never fully stops.
        let spinnerFrame = (audio.beatCount + Int(frame.time * 4)) % Self.spinner.count
        let verb = Self.verbs[(audio.beatCount / 8) % Self.verbs.count]
        let cursorVisible = frame.time.truncatingRemainder(dividingBy: 1) < 0.55 || audio.beatPulse > 0.5

        return VStack(alignment: .leading, spacing: fontSize * 0.55) {
            // Window chrome.
            HStack(spacing: fontSize * 0.4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(ClaudeTheme.cream.opacity(0.18)).frame(width: fontSize * 0.7, height: fontSize * 0.7)
                }
                Spacer()
                Text("claude — beatswall — 80×24").foregroundStyle(dim)
                Spacer()
            }

            // Welcome box.
            VStack(alignment: .leading, spacing: fontSize * 0.25) {
                Text("\(Text("✻ ").foregroundStyle(ClaudeTheme.terracotta))\(Text("Welcome to BeatsWall!").foregroundStyle(ClaudeTheme.cream).bold())")
                Text("  /help for help, /vibe to keep vibing").foregroundStyle(dim)
                Text("  cwd: ~/Music").foregroundStyle(dim)
            }
            .padding(fontSize * 0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: fontSize * 0.4).stroke(ClaudeTheme.terracotta, lineWidth: max(1, fontSize * 0.08)))

            Text("> play something loud").foregroundStyle(ClaudeTheme.cream)

            // Spectrum analyzer.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<Self.spectrumRows, id: \.self) { row in
                    Text(spectrumLine(row: row, spectrum: audio.spectrum))
                        .foregroundStyle(ClaudeTheme.terracotta.mix(with: ClaudeTheme.cream, by: 0.55 * (1 - Double(row) / Double(Self.spectrumRows - 1))))
                }
            }
            .padding(.vertical, fontSize * 0.3)

            Text("\(label("level"))\(level(audio.level))\(label("  bass"))\(level(audio.bass))\(label("  treble"))\(level(audio.treble))")

            Text("\(Text("\(Self.spinner[spinnerFrame]) \(verb)…").foregroundStyle(ClaudeTheme.terracotta))\(label(audio.bpm > 0 ? " (\(Int(audio.bpm.rounded())) bpm · esc to interrupt)" : " (esc to interrupt)"))")

            // Input box.
            Text("\(label("> "))\(Text(cursorVisible ? "█" : " ").foregroundStyle(ClaudeTheme.cream))")
                .padding(.horizontal, fontSize * 0.6)
                .padding(.vertical, fontSize * 0.35)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: fontSize * 0.4).stroke(ClaudeTheme.cream.opacity(0.25), lineWidth: max(1, fontSize * 0.06)))
        }
        .font(.system(size: fontSize, design: .monospaced))
        .lineLimit(1)
        .padding(fontSize * 1.2)
        .frame(width: fontSize * 46)
        .background(ClaudeTheme.ink.opacity(0.85), in: .rect(cornerRadius: fontSize * 0.8))
        .overlay(RoundedRectangle(cornerRadius: fontSize * 0.8).stroke(ClaudeTheme.cream.opacity(0.12), lineWidth: 1))
    }

    /// One row of the block-character spectrum, top row first. Each bin is two blocks wide.
    private func spectrumLine(row: Int, spectrum: [Float]) -> String {
        let rowFromBottom = Self.spectrumRows - 1 - row
        var line = ""
        for value in spectrum {
            let height = Double(value) * Double(Self.spectrumRows)
            let fill = min(max(height - Double(rowFromBottom), 0), 1)
            let block = Self.blocks[Int((fill * 8).rounded())]
            line.append(block)
            line.append(block)
        }
        return line
    }

    private func label(_ text: String) -> Text {
        Text(text).foregroundStyle(ClaudeTheme.cream.opacity(0.45))
    }

    private func level(_ value: Float) -> Text {
        Text(" " + meter(value)).foregroundStyle(ClaudeTheme.terracotta)
    }

    private func meter(_ value: Float, width: Int = 8) -> String {
        let filled = Int((Double(value) * Double(width)).rounded())
        return "▕" + String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled) + "▏"
    }
}
