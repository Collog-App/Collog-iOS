//
//  ReportNotificationRevisionTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 분석 완료 알림은 누르지 않아도 리포트를 다시 읽게 하고, 누를 때만 리포트를 연다.
@MainActor
struct ReportNotificationRevisionTests {
    @Test func bannerNotificationRefreshesDataWithoutOpeningTheReport() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let environment = fixture.environment
        environment.receiveReportNotification(callId: "call-1", title: "분석 완료", message: "확인해 주세요", openReport: false)
        #expect(environment.reportDataRevision == 1)
        #expect(environment.reportNotificationRevision == 0)
    }

    @Test func tappedNotificationRefreshesDataAndOpensTheReport() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let environment = fixture.environment
        environment.receiveReportNotification(callId: "call-1", title: "분석 완료", message: "확인해 주세요", openReport: true)
        #expect(environment.reportDataRevision == 1)
        #expect(environment.reportNotificationRevision == 1)
    }
}
