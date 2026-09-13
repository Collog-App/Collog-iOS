//
//  AppSettingsTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct AppSettingsTests {
    @Test
    func legacyLocalServerMigratesOnlyOnce() throws {
        let suite = "CollogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("http://192.168.0.10:8000", forKey: AppSettings.Key.serverOverride)

        let settings = AppSettings(defaults: defaults)
        #expect(settings.resolvedBaseURL.absoluteString == "https://api.collog.live")
        #expect(settings.requiresServerSessionReset)

        settings.completeServerMigration()

        #expect(defaults.object(forKey: AppSettings.Key.serverOverride) == nil)
        #expect(defaults.object(forKey: AppSettings.Key.backendBaseURL) == nil)
        #expect(!AppSettings(defaults: defaults).requiresServerSessionReset)
    }

    @Test
    func existingProductionSessionSurvivesMigration() throws {
        let suite = "CollogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("https://api.collog.live/", forKey: AppSettings.Key.backendBaseURL)

        #expect(!AppSettings(defaults: defaults).requiresServerSessionReset)
    }
}
