//
//  SafetyNoticeTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 가드레일 약속(2026-11-08)의 응급 안내: 리포트 `safetyNotices`, 통화 extraction `safetyNotice`. 필드가 없어도 된다.
@MainActor
struct SafetyNoticeTests {
    private let notice = "통화 중에 바로 확인이 필요할 수 있는 말씀이 있었어요. 지금 상태를 직접 확인하고, 필요하면 119나 가까운 병원에 연락하세요."

    @Test(arguments: ["", #", "safetyNotices": null"#, #", "safetyNotices": []"#])
    func reportWithoutSafetyNoticesStillDecodes(extra: String) async throws {
        let dto = try await report(extra)
        #expect(dto.safetyNotices?.isEmpty ?? true)
        #expect(WeeklyReport(dto: dto, trend: nil).safetyNotices.isEmpty)
    }

    @Test
    func reportSafetyNoticesKeepServerTextAndSeoulCallDayNewestFirst() async throws {
        let dto = try await report("""
            , "safetyNotices": [
              {"callId": "call-1", "observedAt": "2026-11-06T23:30:00Z", "text": "\(notice)"},
              {"callId": "call-2", "observedAt": "알 수 없음", "text": "\(notice)"},
              {"callId": "call-3", "observedAt": null, "text": "  "},
              {"callId": "call-4", "observedAt": "2026-11-07T15:30:00.123456+00:00", "text": "\(notice)"},
              {"callId": "call-5", "observedAt": "2026-11-05T09:00:00-08:00", "text": "\(notice)"},
              {"callId": "call-6", "text": "\(notice)"}
            ]
            """)
        let notices = WeeklyReport(dto: dto, trend: nil).safetyNotices

        // 최근 통화가 위, 시각을 못 읽은 안내는 아래에 받은 순서대로. 빈 문구는 버린다.
        #expect(notices.map(\.callId) == ["call-4", "call-1", "call-5", "call-2", "call-6"])
        #expect(notices.allSatisfy { $0.text == notice })
        // 통화 날짜는 서울 기준: UTC 11-07 15:30 → 11-08 00:30, UTC 11-06 23:30 → 11-07 08:30
        #expect(notices.map(\.dayText) == ["11월 8일 통화", "11월 7일 통화", "11월 6일 통화", nil, nil])
        #expect(SafetyNotice.calendar.timeZone.identifier == "Asia/Seoul")
    }

    @Test
    func noticeStaysEvenWhenTheWeekHasNoAnalyzedCall() async throws {
        let dto = try await report(
            #", "safetyNotices": [{"callId": "call-1", "observedAt": null, "text": "안내"}]"#,
            count: 0
        )
        let weekly = WeeklyReport(dto: dto, trend: nil)
        #expect(weekly.state == .empty)
        #expect(weekly.safetyNotices.map(\.text) == ["안내"])
    }

    @Test
    func oddNoticeFieldsDoNotBreakTheReport() async throws {
        let dto = try await report(#", "safetyNotices": [{"callId": 7, "observedAt": 123, "text": "안내"}]"#)
        let notices = WeeklyReport(dto: dto, trend: nil).safetyNotices
        #expect(notices.map(\.callId) == [""])
        #expect(notices.first?.dayText == nil)
    }

    @Test
    func extractionDecodesSafetyNotice() async throws {
        let cases: [(body: String, expected: String?)] = [
            (#"{"callId":"c1","parseStatus":"OK","facts":[],"safetyNotice":"안내"}"#, "안내"),
            (#"{"callId":"c1","parseStatus":"EXCLUDED","facts":[],"safetyNotice":null}"#, nil),
            (#"{"callId":"c1","parseStatus":"OK","symptom":"허리","facts":[]}"#, nil)
        ]
        for item in cases {
            let fixture = try TestEnvironment()
            defer { fixture.cleanUp() }
            fixture.respond = { _ in (200, item.body) }
            let extraction = try await fixture.environment.api.extraction(callId: "c1")
            #expect(extraction.safetyNotice == item.expected)
        }
    }

    @Test
    func timelineEntryCarriesOnlyNonBlankNotice() {
        #expect(entry(notice: notice).safetyNotice == notice)
        #expect(entry(notice: "  ").safetyNotice == nil)
        #expect(entry(notice: nil).safetyNotice == nil)
    }

    @Test
    func excludedCallShowsSafetyNoticeWhenServerHasOne() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serve(fixture, state: "ANALYSIS_EXCLUDED", extraction: (200, extractionBody(status: "EXCLUDED", notice: notice)))

        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .unavailable(title, _, safetyNotice) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(title == "분석 대상에서 제외된 통화예요.")
        #expect(safetyNotice == notice)
    }

    @Test(arguments: [404, 500])
    func excludedCallWithoutNoticeKeepsPlainScreen(status: Int) async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serve(fixture, state: "ANALYSIS_EXCLUDED", extraction: (status, #"{"detail":"추출 결과가 아직 없습니다"}"#))

        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .unavailable(title, _, safetyNotice) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(title == "분석 대상에서 제외된 통화예요.")
        #expect(safetyNotice == nil)
    }

    @Test
    func failedCallDoesNotAskForExtraction() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serve(fixture, state: "ANALYSIS_FAILED", extraction: (200, extractionBody(status: "FAILED", notice: notice)))

        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .unavailable(title, _, safetyNotice) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(title == "통화를 분석하지 못했어요.")
        #expect(safetyNotice == nil)
        #expect(!fixture.paths.contains { $0.hasSuffix("/extraction") })
    }

    @Test
    func analyzedCallShowsNoticeAboveItsAnalysis() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serve(fixture, state: "ANALYZED", extraction: (200, extractionBody(status: "OK", notice: notice)))

        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .ready(entry) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(entry.safetyNotice == notice)
    }

    @Test
    func unfinishedCallIsPending() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serve(fixture, state: "PROCESSING", extraction: (404, "{}"))

        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case .pending = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
    }

    // MARK: - Fixtures

    private func report(_ extra: String, count: Int = 1) async throws -> ReportDTO {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in
            (200, """
            {"parentId":"mom","period":"WEEKLY","from":"2026-11-02","to":"2026-11-08","state":"READY",
             "disclaimer":"","promotedSignals":[],"acuteSignals":[],"conversationItems":{},
             "repeatObservation":{"count":0,"callsWithRepeat":0,"label":""},"acousticTrends":[],
             "analyzedCallCount":\(count)\(extra)}
            """)
        }
        return try await fixture.environment.api.report(parentId: "mom")
    }

    private func serve(_ fixture: TestEnvironment, state: String, extraction: (Int, String)) {
        fixture.respond = { request in
            switch request.url?.path ?? "" {
            case "/v1/calls/c1":
                (200, """
                {"callId":"c1","parentId":"mom","childId":"me","state":"\(state)","timeSlot":null,
                 "startedAt":"2026-11-05T03:00:00Z","endedAt":"2026-11-05T03:02:00Z","durationSec":120,
                 "recorded":true,"parentSpeechSec":40,"askedQuestionIds":[],"rawAudioPurgedAt":null}
                """)
            case "/v1/calls/c1/extraction":
                extraction
            default:
                (404, #"{"detail":"없음"}"#)
            }
        }
    }

    private func extractionBody(status: String, notice: String) -> String {
        #"{"callId":"c1","parseStatus":"\#(status)","facts":[],"safetyNotice":"\#(notice)"}"#
    }

    private func entry(notice: String?) -> CallTimelineEntry {
        let call = CallSummaryDTO(
            callId: "c1", parentId: "mom", state: "ANALYZED", timeSlot: nil,
            startedAt: Date(), endedAt: Date(), durationSec: 120, recorded: true, parentSpeechSec: nil
        )
        let extraction = ExtractionDTO(
            callId: "c1", parseStatus: "OK", symptom: nil, medication: nil, activity: nil, sleep: nil,
            safetyNotice: notice
        )
        return CallTimelineEntry(
            bundle: CallAnalysisBundle(call: call, features: nil, extraction: extraction, transcript: nil),
            baselines: [:]
        )
    }
}
