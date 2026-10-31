//
//  UpdateChecker.swift
//  BeatsWall
//
//  Looks for a newer beta build in the latest.json that Tools/make-dmg.sh writes, so testers
//  hear about new builds without being told.
//

import Foundation
import Observation
import UserNotifications

@Observable
final class UpdateChecker {
    struct Release: Decodable, Equatable {
        let build: Int
        let version: String
        let notes: String?
        let download: URL
    }

    /// A build newer than this one, once one has been found.
    private(set) var available: Release?

    @ObservationIgnored private var timer: Timer?
    private static let notifiedKey = "notifiedUpdateBuild"

    func start() {
        guard timer == nil, let url = BetaInfo.updateURL else { return }
        check(url)
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(url) }
        }
    }

    private func check(_ url: URL) {
        Task {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let release = try? JSONDecoder().decode(Release.self, from: data),
                  release.build > Int(BetaInfo.build) ?? .max else { return }
            available = release
            notifyOnce(release)
        }
    }

    /// One notification per new build, however many times it's found.
    private func notifyOnce(_ release: Release) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.notifiedKey) < release.build else { return }
        defaults.set(release.build, forKey: Self.notifiedKey)
        let center = UNUserNotificationCenter.current()
        Task {
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "A new BeatsWall beta is ready"
            content.body = "Build \(release.build) is out. Download it from the BeatsWall menu."
            try? await center.add(UNNotificationRequest(identifier: "build-\(release.build)", content: content, trigger: nil))
        }
    }
}
