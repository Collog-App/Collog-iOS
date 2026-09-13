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
        static let productionServerConfigured = "settings.productionServerConfigured"
        static let callNotificationsEnabled = "settings.callNotificationsEnabled"
        static let reportNotificationsEnabled = "settings.reportNotificationsEnabled"
        static let questionVoiceEnabled = "settings.questionVoiceEnabled"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let guestMode = "settings.guestMode"
    }

    private let defaults: UserDefaults
    let backendBaseURL = "https://api.collog.live"
    let requiresServerSessionReset: Bool

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
        let previousAddress = defaults.string(forKey: Key.serverOverride)
            ?? defaults.string(forKey: Key.backendBaseURL) ?? ""
        requiresServerSessionReset = !defaults.bool(forKey: Key.productionServerConfigured)
            && previousAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != backendBaseURL
        callNotificationsEnabled = defaults.object(forKey: Key.callNotificationsEnabled) as? Bool ?? true
        reportNotificationsEnabled = defaults.object(forKey: Key.reportNotificationsEnabled) as? Bool ?? true
        questionVoiceEnabled = defaults.object(forKey: Key.questionVoiceEnabled) as? Bool ?? true
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        isGuestMode = defaults.bool(forKey: Key.guestMode)
    }

    var resolvedBaseURL: URL {
        URL(string: backendBaseURL)!
    }

    func completeServerMigration() {
        defaults.removeObject(forKey: Key.backendBaseURL)
        defaults.removeObject(forKey: Key.serverOverride)
        defaults.set(true, forKey: Key.productionServerConfigured)
    }
}
