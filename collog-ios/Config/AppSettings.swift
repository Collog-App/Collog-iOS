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
        static let callNotificationsEnabled = "settings.callNotificationsEnabled"
        static let reportNotificationsEnabled = "settings.reportNotificationsEnabled"
        static let questionVoiceEnabled = "settings.questionVoiceEnabled"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let guestMode = "settings.guestMode"
    }

    enum Default {
        static let backendBaseURL = "http://127.0.0.1:8080"
    }

    private let defaults: UserDefaults

    var backendBaseURL: String {
        didSet { defaults.set(backendBaseURL, forKey: Key.backendBaseURL) }
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
        backendBaseURL = defaults.string(forKey: Key.backendBaseURL) ?? Default.backendBaseURL
        callNotificationsEnabled = defaults.object(forKey: Key.callNotificationsEnabled) as? Bool ?? true
        reportNotificationsEnabled = defaults.object(forKey: Key.reportNotificationsEnabled) as? Bool ?? true
        questionVoiceEnabled = defaults.object(forKey: Key.questionVoiceEnabled) as? Bool ?? true
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        isGuestMode = defaults.bool(forKey: Key.guestMode)
    }

    var resolvedBaseURL: URL {
        URL(string: backendBaseURL) ?? URL(string: Default.backendBaseURL)!
    }
}
