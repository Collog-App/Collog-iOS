//
//  AppEnvironment.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class AppEnvironment {
    let settings: AppSettings
    let session: AuthSession
    let family: FamilyStore
    private let networkSession: URLSession
    var reportNotificationRevision = 0
    private(set) var reportNotifications: [ReceivedReportNotification] = []

    init(
        settings: AppSettings = AppSettings(),
        session: AuthSession = AuthSession(),
        family: FamilyStore = FamilyStore(),
        networkSession: URLSession = .shared
    ) {
        self.settings = settings
        self.session = session
        self.family = family
        self.networkSession = networkSession
        session.onAccountChanged = { [weak self] in
            self?.family.reset()
            self?.reportNotifications = []
        }
        if settings.requiresServerSessionReset { session.signOut() }
        if session.storageError == nil { settings.completeServerMigration() }
        if !session.isAuthenticated { family.reset() }
    }

    func subjectParentId() async -> String? {
        guard let user = session.user else { return nil }
        if user.role == UserRoleOption.parent.rawValue { return user.id }
        guard let familyId = user.familyId else { return nil }
        let members = try? await api.members(familyId: familyId)
        return members?.first { $0.userId != nil && $0.role != "CHILD" && $0.userId != user.id }?.userId
    }

    var api: CollogAPI {
        CollogAPI(
            client: CollogAPIClient(
                baseURL: settings.resolvedBaseURL,
                accessToken: session.accessToken,
                session: networkSession,
                authentication: session
            )
        )
    }

    func signOut() async {
        let refreshToken = session.refreshToken
        let api = api
        session.signOut()
        if let refreshToken { try? await api.logout(refreshToken: refreshToken) }
    }

    func receiveReportNotification(callId: String, title: String, message: String, openReport: Bool) {
        guard session.isAuthenticated else { return }
        if !reportNotifications.contains(where: { $0.id == callId }) {
            reportNotifications.insert(
                ReceivedReportNotification(id: callId, title: title, message: message, date: Date()),
                at: 0
            )
        }
        if openReport { reportNotificationRevision += 1 }
    }
}

struct ReceivedReportNotification: Identifiable {
    let id: String
    let title: String
    let message: String
    let date: Date
}
