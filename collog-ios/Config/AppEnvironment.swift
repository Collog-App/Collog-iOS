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
    let health: HealthLink
    let usage: UsageEventLog
    private let networkSession: URLSession
    @ObservationIgnored var beforeSignOut: (() async -> Void)?
    var reportNotificationRevision = 0
    /// 리포트·타임라인에서 지금 보는 사람에 따른 색. 탭바·전화 버튼이 따라간다.
    var viewerAccent: ViewerAccent = .family
    /// 분석 완료 알림을 받을 때마다(누르지 않아도) 오른다. 리포트·홈 화면이 이미 불러 둔 데이터를 다시 읽는다.
    private(set) var reportDataRevision = 0
    private(set) var reportNotifications: [ReceivedReportNotification] = []
    /// 리포트 알림을 눌러 리포트로 가는 중이면 누른 시각. 리포트 화면이 들어올 때 한 번 읽고 지운다(이용 기록 `report_view`).
    @ObservationIgnored private var reportNotificationOpenedAt: Date?
    /// 알림을 누른 뒤 이 안에 리포트 화면이 들어오지 않으면 그 표시는 나중의 일반 열람에 붙이지 않는다.
    static let reportNotificationEntryWindow: TimeInterval = 10

    init(
        settings: AppSettings = AppSettings(),
        session: AuthSession = AuthSession(),
        family: FamilyStore = FamilyStore(),
        health: HealthLink = HealthLink(),
        usage: UsageEventLog = UsageEventLog(),
        networkSession: URLSession = .shared
    ) {
        self.settings = settings
        self.session = session
        self.family = family
        self.health = health
        self.usage = usage
        self.networkSession = networkSession
        session.onAccountChanged = { [weak self] in
            self?.family.reset()
            self?.reportNotifications = []
            self?.reportNotificationOpenedAt = nil
        }
        if settings.requiresServerSessionReset { session.signOut() }
        if session.storageError == nil { settings.completeServerMigration() }
        if !session.isAuthenticated { family.reset() }
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
        await beforeSignOut?()
        let refreshToken = session.refreshToken
        let api = api
        usage.clear()
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
        reportDataRevision += 1
        if openReport {
            reportNotificationOpenedAt = Date()
            reportNotificationRevision += 1
        }
    }

    /// 리포트 화면이 알림을 눌러 열렸는지 한 번만 알려 준다. 누른 지 10초가 지난 표시는 버린다.
    func takeReportNotificationEntry(now: Date = Date()) -> Bool {
        defer { reportNotificationOpenedAt = nil }
        guard let openedAt = reportNotificationOpenedAt else { return false }
        return now.timeIntervalSince(openedAt) <= Self.reportNotificationEntryWindow
    }
}

struct ReceivedReportNotification: Identifiable {
    let id: String
    let title: String
    let message: String
    let date: Date
}
