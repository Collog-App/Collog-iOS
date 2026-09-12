//
//  AppSettings.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class AppSettings {
    enum Key {
        static let backendBaseURL = "settings.backendBaseURL"
        static let serverOverride = "settings.serverOverride"
        static let callNotificationsEnabled = "settings.callNotificationsEnabled"
        static let reportNotificationsEnabled = "settings.reportNotificationsEnabled"
        static let questionVoiceEnabled = "settings.questionVoiceEnabled"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let guestMode = "settings.guestMode"
    }

    enum Default {
        static let backendBaseURL = "https://1-201-117-44.sslip.io"
        static let legacyBackendBaseURLs = [
            "http://127.0.0.1:8080",
            "http://1.201.117.44:8080"
        ]
    }

    private let defaults: UserDefaults

    var backendBaseURL: String {
        didSet {
            defaults.set(backendBaseURL, forKey: Key.serverOverride)
        }
    }

    var callNotificationsEnabled: Bool {
        didSet { defaults.set(callNotificationsEnabled, forKey: Key.callNotificationsEnabled) }
    }

    var reportNotificationsEnabled: Bool {
        didSet { defaults.set(reportNotificationsEnabled, forKey: Key.reportNotificationsEnabled) }
    }

    var questionVoiceEnabled: Bool {
        didSet { defaults.set(questionVoiceEnabled, forKey: Key.questionVoiceEnabled) }
    }

    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    var isGuestMode: Bool {
        didSet { defaults.set(isGuestMode, forKey: Key.guestMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedBaseURL = defaults.string(forKey: Key.backendBaseURL)
        let fallback = if let storedBaseURL, !Default.legacyBackendBaseURLs.contains(storedBaseURL) {
            storedBaseURL
        } else {
            Default.backendBaseURL
        }
        backendBaseURL = defaults.string(forKey: Key.serverOverride)
            .flatMap(Self.normalizedServerAddress) ?? fallback
        callNotificationsEnabled = defaults.object(forKey: Key.callNotificationsEnabled) as? Bool ?? true
        reportNotificationsEnabled = defaults.object(forKey: Key.reportNotificationsEnabled) as? Bool ?? true
        questionVoiceEnabled = defaults.object(forKey: Key.questionVoiceEnabled) as? Bool ?? true
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        isGuestMode = defaults.bool(forKey: Key.guestMode)
    }

    var resolvedBaseURL: URL {
        URL(string: backendBaseURL) ?? URL(string: Default.backendBaseURL)!
    }

    nonisolated static func normalizedServerAddress(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              !host.contains(where: \.isWhitespace),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else { return nil }
        if let port = components.port, !(1...65535).contains(port) { return nil }
        components.scheme = scheme
        components.host = host.lowercased()
        components.path = ""
        return components.url?.absoluteString
    }
}
