//
//  BetaInfo.swift
//  BeatsWall
//
//  Version and private-beta details. The expiry date and feedback address are filled in by
//  Tools/make-dmg.sh; local builds leave them empty (no expiry).
//

import AppKit

enum BetaInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    static var versionDescription: String { "Beta \(version) (\(build))" }

    /// The last day this build runs, if it's a beta build.
    static var expiresAt: Date? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "BWBetaExpires") as? String, !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        // Runs through the end of that day.
        return formatter.date(from: text).map { $0.addingTimeInterval(86_400) }
    }

    static var hasExpired: Bool {
        expiresAt.map { Date() >= $0 } ?? false
    }

    static var feedbackEmail: String? {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "BWFeedbackEmail") as? String, email.contains("@") else { return nil }
        return email
    }

    /// Tells a tester this build has ended, then quits.
    static func showExpiredAndQuit() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "This BeatsWall beta has ended"
        alert.informativeText = "Thanks for testing! Ask for the newest build to keep going."
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
