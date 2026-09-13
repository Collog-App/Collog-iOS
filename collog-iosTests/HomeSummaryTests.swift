//
//  HomeSummaryTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct HomeSummaryTests {
    @Test
    func firstAnalysisShowsConversationWithoutAcousticTrend() throws {
        let summary = try #require(FamilyHealthSummary(dto: report(), memberName: "부모님", baseline: nil))
        #expect(summary.trend == nil)
        #expect(summary.conversationGroups.first?.items == ["산책했다고 이야기했어요."])
        #expect(summary.stats.first?.value == "1")
        #expect(summary.headline == "통화 내용을 먼저 정리했어요")
    }

    @Test
    func zeroAnalyzedCallsDoNotExposeOldConversationContent() {
        #expect(FamilyHealthSummary(dto: report(count: 0), memberName: "부모님", baseline: nil) == nil)
    }

    @Test
    func readyReportWithoutSignalDoesNotAssertOverallHealth() throws {
        let summary = try #require(FamilyHealthSummary(
            dto: report(state: "READY"), memberName: "부모님", baseline: baseline()
        ))
        #expect(summary.headline == "이번 기간의 통화 기록이에요")
    }

    @Test
    func collectingReportStaysNeutralEvenWithReadyMetricBaseline() throws {
        let summary = try #require(FamilyHealthSummary(dto: report(), memberName: "부모님", baseline: baseline()))
        #expect(summary.headline == "통화 내용을 먼저 정리했어요")
    }

    @Test
    func chartDoesNotTreatObservedExtremesAsPersonalBaseline() throws {
        let data = AcousticTrendDTO(metric: "SPEECH_RATE", points: [
            AcousticTrendPointDTO(date: "2026-09-12", value: 190, unit: nil),
            AcousticTrendPointDTO(date: "2026-09-13", value: 210, unit: nil)
        ])
        #expect(try #require(TrendSeries(trend: data, baseline: nil)).hasPersonalBaseline == false)
        #expect(try #require(TrendSeries(trend: data, baseline: baseline())).hasPersonalBaseline)
    }

    @Test
    func homeLoadsFirstSummaryAndQuestionsWithoutTrend() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            switch request.url?.path {
            case "/v1/parents/me/calls": (200, #"{"calls":[]}"#)
            case "/v1/parents/me/baseline": (200, #"{"baselines":[]}"#)
            case "/v1/parents/me/reports": (200, """
                {"parentId":"me","period":"WEEKLY","from":"2026-09-07","to":"2026-09-13",
                "state":"BASELINE_COLLECTING","disclaimer":"","promotedSignals":[],"acuteSignals":[],
                "conversationItems":{"activity":["산책했다고 이야기했어요."]},
                "repeatObservation":{"count":0,"callsWithRepeat":0,"label":""},
                "acousticTrends":[],"analyzedCallCount":1}
                """)
            default:
                Issue.record("Unexpected home request")
                throw URLError(.unsupportedURL)
            }
        }
        let model = HomeViewModel()
        await model.refresh(using: fixture.environment, contact: nil)
        #expect(model.healthSummary?.conversationGroups.count == 1)
        #expect(model.healthFeedback?.followUps.count == 1)
        #expect(model.loadError == nil)
        #expect(model.isLoaded)
    }

    private func baseline() -> BaselineDTO {
        BaselineDTO(
            metric: "SPEECH_RATE", timeSlot: "ALL", kind: "ROLLING", status: "READY",
            sampleCount: 10, requiredCount: 10, median: 200, mad: 5
        )
    }

    private func report(count: Int = 1, state: String = "BASELINE_COLLECTING") -> ReportDTO {
        ReportDTO(
            parentId: "parent", period: "WEEKLY", from: "2026-09-07", to: "2026-09-13",
            state: state, emptyMessage: nil, disclaimer: "", advisory: nil,
            promotedSignals: [], acuteSignals: [], conversationItems: ["activity": ["산책했다고 이야기했어요."]],
            repeatObservation: RepeatObservationDTO(count: 0, callsWithRepeat: 0, label: ""),
            acousticTrends: [], recentAcousticHistory: nil, analyzedCallCount: count,
            containsDemoData: false, demoDataNotice: nil
        )
    }
}
