//
//  ReportViewEventTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 이용 기록 `report_view`: 사람이 리포트에 들어온 순간과 보는 사람을 바꾼 순간에만 남는다.
@MainActor
struct ReportViewEventTests {
    @Test func reportEntryIsRecordedOnceAndAutomaticReloadsRecordNothing() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = reportResponses(contacts: ["mom"])
        await fixture.environment.family.refresh(using: fixture.environment)
        let usage = fixture.environment.usage
        let model = TimelineViewModel(selectedTabIndex: 0)

        model.recordReportEntry(using: fixture.environment)
        // 분석 화면에서 돌아와 화면이 다시 나타나도 한 번뿐이다
        model.recordReportEntry(using: fixture.environment)
        await model.refresh(using: fixture.environment)
        // 분석 완료 알림·건강 동기화·당겨서 새로 고침(forceReload), 앱 복귀 재확인, 주 넘기기
        await model.refresh(using: fixture.environment, forceReload: true)
        await model.revalidateSharing(using: fixture.environment)
        model.setWeek(-1)
        await model.refresh(using: fixture.environment)
        await model.loadPage(-2, using: fixture.environment, forceReload: true)

        #expect(usage.pendingEvents.count == 1)
        let entry = try #require(usage.pendingEvents.first)
        #expect(entry.name == "report_view")
        #expect(entry.code == "DIRECT")
        #expect(entry.subjectId == "mom")

        // 보는 사람을 「나」로 바꾸면 내 ID 로 한 번
        model.selectMember(try #require(model.subjects(using: fixture.environment).last))
        model.recordReportSubjectChange(using: fixture.environment)
        await model.refresh(using: fixture.environment)
        #expect(usage.pendingEvents.map(\.subjectId) == ["mom", "me"])
        #expect(usage.pendingEvents.map(\.code) == ["DIRECT", "DIRECT"])
    }

    @Test func notificationTapMarksOnlyTheReportItOpened() async throws {
        // 아직 아무 가족과도 연결되지 않은 사람: 가족 목록을 읽으면 보는 사람은 「나」뿐이다
        let fixture = try TestEnvironment(role: "CHILD", familyId: nil)
        defer { fixture.cleanUp() }
        let environment = fixture.environment
        let usage = environment.usage
        await environment.family.refresh(using: environment)

        environment.receiveReportNotification(callId: "call", title: "리포트", message: "", openReport: true)
        // 타임라인 탭은 대상이 아니고, 알림 표시도 가져가지 않는다
        let timeline = TimelineViewModel(selectedTabIndex: 1)
        timeline.recordReportEntry(using: environment)
        timeline.recordReportSubjectChange(using: environment)
        #expect(usage.pendingEvents.isEmpty)

        TimelineViewModel(selectedTabIndex: 0).recordReportEntry(using: environment)
        TimelineViewModel(selectedTabIndex: 0).recordReportEntry(using: environment)
        // 배너로만 받은 알림(누르지 않음)은 리포트로 가지 않는다
        environment.receiveReportNotification(callId: "call-2", title: "리포트", message: "", openReport: false)
        TimelineViewModel(selectedTabIndex: 0).recordReportEntry(using: environment)

        #expect(usage.pendingEvents.map(\.code) == ["NOTIFICATION", "DIRECT", "DIRECT"])
        #expect(usage.pendingEvents.allSatisfy { $0.subjectId == "me" })
    }

    /// 앱이 막 떠서 가족 목록을 읽기 전에 들어오면 보는 사람이 곧 첫 가족으로 바뀐다. 목록이 정해진 뒤 한 번 남긴다.
    @Test func reportEntryWaitsForTheFamilyList() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = reportResponses(contacts: ["mom"])
        let environment = fixture.environment
        let usage = environment.usage
        let model = TimelineViewModel(selectedTabIndex: 0)

        environment.receiveReportNotification(callId: "call", title: "리포트", message: "", openReport: true)
        model.recordReportEntry(using: environment)
        #expect(environment.family.memberUserIds == nil)
        #expect(usage.pendingEvents.isEmpty)

        await environment.family.refresh(using: environment)
        model.recordReportEntry(using: environment)
        model.recordReportEntry(using: environment)
        #expect(usage.pendingEvents.map(\.subjectId) == ["mom"])
        // 알림으로 들어왔다는 것은 들어온 순간에 정해 둔다
        #expect(usage.pendingEvents.map(\.code) == ["NOTIFICATION"])
    }

    private func reportResponses(contacts: [String]) -> (URLRequest) throws -> (Int, String) {
        let members = contacts.map { id in
            """
            {"memberId":"\(id)","userId":"\(id)","name":"\(id)","relation":"MOTHER","status":"ACTIVE","role":"PARENT"}
            """
        }
        let body = "{\"members\":[\(members.joined(separator: ","))]}"
        return { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/members") { return (200, body) }
            if path.hasSuffix("/calls") { return (200, #"{"calls":[]}"#) }
            if path.hasSuffix("/baseline") { return (200, #"{"baselines":[]}"#) }
            if path.hasSuffix("/daily-questions") { return (200, #"{"source":"fixture","questions":[]}"#) }
            if path.hasPrefix("/v1/events") {
                Issue.record("자동 전송을 끈 시험에서 이벤트를 보냈다")
            }
            return (503, "{}")
        }
    }
}
