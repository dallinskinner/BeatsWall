//
//  FeedbackView.swift
//  BeatsWall
//

import SwiftUI

/// Write a note to the BeatsWall team, with a few details attached so issues are easy to chase.
struct FeedbackView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openURL) private var openURL
    @State private var message = ""
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send Feedback")
                .font(.title2.weight(.semibold))
            Text("Bugs, ideas, a wallpaper you'd love to see: anything helps. These details are attached so problems are easier to track down:")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $message)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: .rect(cornerRadius: 8))
                .frame(minHeight: 160)
                .overlay(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("What happened, or what would you like?")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            Text(diagnostics)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: .rect(cornerRadius: 8))

            HStack {
                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    copied = true
                }
                if let email = BetaInfo.feedbackEmail {
                    Button("Send Email…") { sendEmail(to: email) }
                        .keyboardShortcut(.defaultAction)
                        .disabled(message.isEmpty)
                }
            }
            if BetaInfo.feedbackEmail == nil {
                Text("Copy this and send it to whoever invited you to the beta.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var diagnostics: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let audio: String
        switch appState.audioStatus {
        case .listening: audio = appState.liveAudio.secondsSinceSignal < 4 ? "listening" : "listening, no signal"
        case .stopped: audio = "stopped"
        case .failed(let message): audio = "failed: \(message)"
        }
        var lines = [
            "BeatsWall \(BetaInfo.versionDescription)",
            "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) · \(NSScreen.screens.count) display(s)",
            "Wallpaper: \(appState.displayedWallpaper.id)\(appState.isShuffling ? " (shuffle)" : "")",
            "Audio: \(audio)",
        ]
        if appState.showsLyrics { lines.append("Lyrics: \(appState.lyrics.status)") }
        if let reason = appState.pauseReason { lines.append(reason) }
        return lines.joined(separator: "\n")
    }

    private var report: String {
        "\(message)\n\n---\n\(diagnostics)"
    }

    private func sendEmail(to email: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "BeatsWall feedback (\(BetaInfo.versionDescription))"),
            URLQueryItem(name: "body", value: report),
        ]
        if let url = components.url {
            openURL(url)
            dismissWindow()
        }
    }
}
