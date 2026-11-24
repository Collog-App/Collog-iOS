//
//  SharingOffTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 가족이 「가족 공유 데이터 범위」에서 나에게 공유를 끄면 서버는 그 사람의 리포트·타임라인을 403 으로 막는다.
/// 불러오기 실패가 아니라 볼 수 없는 항목으로 보이고, 다른 오류는 지금처럼 오류로 남는다.
@MainActor
struct SharingOffTests {
    private let denied = #"{"code":"SCOPE_DENIED","message":"열람 권한이 없는 항목입니다"}"#

    @Test
    func notSharedCopyExplainsWhereSharingIsTurnedOn() {
        #expect(NotSharedStateView.title == "이 가족이 공유하지 않은 항목이에요")
        #expect(NotSharedStateView.message == "가족이 설정의 「가족 공유 데이터 범위」에서 공유를 켜면 볼 수 있어요.")
    }

    // MARK: - 리포트·타임라인

    @Test
    func timelineTurnedOffIsNotAnError() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (403, denied), report: (200, reportBody()))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        let page = model.page(for: 0)
        #expect(page.isLoaded)
        #expect(page.timelineNotShared)
        #expect(page.timelineError == nil)
        #expect(page.entries.isEmpty)
        #expect(page.calls.isEmpty)
        // 리포트는 따로 공유한다
        #expect(!page.reportNotShared)
        #expect(page.reportError == nil)
        #expect(page.report.state != .empty)
    }

    @Test
    func reportTurnedOffIsNotAnError() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, #"{"calls":[]}"#), report: (403, denied))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        let page = model.page(for: 0)
        #expect(page.reportNotShared)
        #expect(page.reportError == nil)
        #expect(page.report.state == .empty)
        #expect(!page.timelineNotShared)
        #expect(page.timelineError == nil)
    }

    @Test
    func sharingTurnedBackOnClearsTheNotSharedState() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (403, denied), report: (403, denied))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)
        #expect(model.page(for: 0).reportNotShared)
        #expect(model.page(for: 0).timelineNotShared)

        serve(fixture, calls: (200, #"{"calls":[]}"#), report: (200, reportBody()))
        await model.loadPage(0, using: fixture.environment, forceReload: true)
        #expect(!model.page(for: 0).reportNotShared)
        #expect(!model.page(for: 0).timelineNotShared)
        #expect(model.page(for: 0).report.state != .empty)
    }

    @Test(arguments: [404, 500, 503])
    func otherFailuresStayErrorsWithRetry(status: Int) async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let failure = (status, #"{"code":"ERROR","message":"잠시 후 다시 시도해주세요"}"#)
        serve(fixture, calls: failure, report: failure)
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        let page = model.page(for: 0)
        #expect(!page.reportNotShared)
        #expect(!page.timelineNotShared)
        #expect(page.reportError == "잠시 후 다시 시도해주세요")
        #expect(page.timelineError == "잠시 후 다시 시도해주세요")
    }

    // MARK: - 홈

    @Test
    func homeShowsNotSharedInsteadOfLoadFailureWhenReportIsOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, #"{"calls":[]}"#), report: (403, denied))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)

        #expect(model.isLoaded)
        #expect(model.isReportNotShared)
        #expect(model.loadError == nil)
        #expect(model.recentCallsError == nil)
        #expect(model.healthSummary == nil)
    }

    @Test
    func homeDoesNotTreatHiddenCallHistoryAsAFailure() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (403, denied), report: (200, reportBody()))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)

        #expect(model.recentCallsError == nil)
        #expect(model.recentCalls.isEmpty)
        #expect(model.lastCallText == "통화 기록을 공유하지 않았어요")
        #expect(!model.isReportNotShared)
        #expect(model.healthSummary != nil)
    }

    @Test
    func homeKeepsOtherFailuresAsErrorsAndClearsNotSharedOnReload() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (403, denied), report: (403, denied))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)
        #expect(model.isReportNotShared)

        let failure = (500, #"{"code":"ERROR","message":"잠시 후 다시 시도해주세요"}"#)
        serve(fixture, calls: failure, report: failure)
        await model.refresh(using: fixture.environment, contact: contact)
        #expect(!model.isReportNotShared)
        #expect(model.loadError == "잠시 후 다시 시도해주세요")
        #expect(model.recentCallsError == "잠시 후 다시 시도해주세요")
        #expect(model.lastCallText == "통화 기록을 불러오지 못했어요")
    }

    // MARK: - 보고 있는 동안 공유가 바뀔 때 (앱으로 돌아오면 다시 확인한다)

    @Test
    func homeDropsWhatItShowedOnceSharingIsTurnedOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, callsBody()), report: (200, reportBody()))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)
        #expect(model.healthSummary != nil)
        #expect(model.recentCalls.count == 1)

        serve(fixture, calls: (403, denied), report: (403, denied))
        await model.refreshCalls(using: fixture.environment, contact: contact)

        #expect(model.isReportNotShared)
        #expect(model.healthSummary == nil)
        #expect(model.healthFeedback == nil)
        #expect(model.recentCalls.isEmpty)
        #expect(model.lastCallText == "통화 기록을 공유하지 않았어요")
    }

    @Test
    func homeDropsTheSummaryWhenOnlyTheReportIsTurnedOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, callsBody()), report: (200, reportBody()))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)
        #expect(model.healthSummary != nil)

        serve(fixture, calls: (200, callsBody()), report: (403, denied))
        await model.refreshCalls(using: fixture.environment, contact: contact)

        #expect(model.isReportNotShared)
        #expect(model.healthSummary == nil)
        // 통화 기록은 따로 공유한다
        #expect(model.recentCalls.count == 1)
    }

    @Test
    func homeReadsAgainOnceSharingIsTurnedBackOn() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (403, denied), report: (403, denied))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)
        #expect(model.isReportNotShared)

        serve(fixture, calls: (200, callsBody()), report: (200, reportBody()))
        await model.refreshCalls(using: fixture.environment, contact: contact)

        #expect(!model.isReportNotShared)
        #expect(model.healthSummary != nil)
        #expect(model.recentCalls.count == 1)
    }

    @Test
    func homeKeepsTheScreenWhenAQuietReloadFailsForAnotherReason() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, callsBody()), report: (200, reportBody()))
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: contact)

        let failure = (503, #"{"code":"ERROR","message":"잠시 후 다시 시도해주세요"}"#)
        serve(fixture, calls: failure, report: failure)
        await model.refreshCalls(using: fixture.environment, contact: contact)

        #expect(model.healthSummary != nil)
        #expect(model.recentCalls.count == 1)
        #expect(!model.isReportNotShared)
        #expect(model.loadError == nil)
    }

    @Test
    func timelineDropsLoadedWeeksOnceSharingIsTurnedOff() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, #"{"calls":[]}"#), report: (200, reportBody()))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.refresh(using: fixture.environment)
        #expect(model.page(for: 0).report.state != .empty)
        #expect(model.page(for: -1).report.state != .empty)

        serve(fixture, calls: (403, denied), report: (403, denied))
        await model.revalidateSharing(using: fixture.environment)

        // 공유는 주마다가 아니라 사람마다 끄므로, 불러 둔 다른 주도 남지 않는다
        for offset in [0, -1] {
            let page = model.page(for: offset)
            #expect(page.isLoaded)
            #expect(page.reportNotShared)
            #expect(page.timelineNotShared)
            #expect(page.report.state == .empty)
        }
    }

    @Test
    func timelineLeavesTheScreenAloneWhenSharingDidNotChange() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serve(fixture, calls: (200, #"{"calls":[]}"#), report: (200, reportBody()))
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.refresh(using: fixture.environment)
        let reportRequests = { fixture.paths.filter { $0 == "/v1/parents/mom/reports" }.count }
        let before = reportRequests()

        await model.revalidateSharing(using: fixture.environment)
        // 조용히 한 번 묻기만 하고 주를 다시 읽지 않는다
        #expect(reportRequests() == before + 1)
        #expect(model.page(for: 0).isLoaded)
        #expect(model.page(for: 0).report.state != .empty)

        // 연결·서버 오류로는 공유가 꺼졌다고 보지 않는다
        let failure = (503, #"{"code":"ERROR","message":"잠시 후 다시 시도해주세요"}"#)
        serve(fixture, calls: failure, report: failure)
        await model.revalidateSharing(using: fixture.environment)
        #expect(model.page(for: 0).report.state != .empty)
        #expect(!model.page(for: 0).reportNotShared)
        #expect(model.page(for: 0).reportError == nil)
    }

    // MARK: - Fixtures

    private var contact: FamilyContact {
        FamilyContact(id: "mom", userId: "mom", name: "mom", relation: "MOTHER", lastCallText: "")
    }

    private func serve(_ fixture: TestEnvironment, calls: (Int, String), report: (Int, String)) {
        fixture.respond = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/members") {
                return (200, """
                {"members":[{"memberId":"mom","userId":"mom","name":"mom","relation":"MOTHER","status":"ACTIVE"}]}
                """)
            }
            if path.hasSuffix("/daily-questions") { return (200, #"{"source":"fixture","questions":[]}"#) }
            if path.hasSuffix("/baseline") { return (200, #"{"baselines":[]}"#) }
            if path == "/v1/parents/mom/calls" { return calls }
            if path == "/v1/parents/mom/reports" { return report }
            return (404, #"{"code":"NOT_FOUND","message":"없음"}"#)
        }
    }

    private func callsBody() -> String {
        """
        {"calls":[{"callId":"c1","parentId":"mom","childId":"me","state":"ANALYZED","timeSlot":null,
         "startedAt":"2026-11-05T03:00:00Z","endedAt":"2026-11-05T03:02:00Z","durationSec":120,
         "recorded":true,"parentSpeechSec":60}]}
        """
    }

    private func reportBody() -> String {
        """
        {"parentId":"mom","period":"WEEKLY","from":"2026-11-02","to":"2026-11-08","state":"READY",
         "disclaimer":"","promotedSignals":[],"acuteSignals":[],
         "conversationItems":{"activity":["산책했다고 이야기했어요."]},
         "repeatObservation":{"count":0,"callsWithRepeat":0,"label":""},"acousticTrends":[],
         "analyzedCallCount":1}
        """
    }
}
