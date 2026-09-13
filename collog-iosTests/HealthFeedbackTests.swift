//
//  HealthFeedbackTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Testing
@testable import collog_ios

@MainActor
struct HealthFeedbackTests {
    @Test
    func firstAnalyzedCallProvidesQuestionsWithoutTrendsOrAdvisory() throws {
        let feedback = try #require(HealthFeedback(dto: report(items: [
            "sleep": ["잠들기까지 한 시간이 걸렸다고 이야기했어요."],
            "activity": ["어제 산책했다고 이야기했어요."]
        ])))

        #expect(feedback.followUps.map(\.category) == ["활동", "수면"])
        #expect(feedback.followUps.last?.summary == "잠들기까지 한 시간이 걸렸다고 이야기했어요.")
        #expect(feedback.followUps.last?.question == "최근 통화에서 나눈 수면 이야기는 요즘 어때요?")
        #expect(feedback.followUps.first?.question == "최근 통화에서 나눈 활동 이야기에서 달라진 점이 있어요?")
    }

    @Test
    func absentTopicsDoNotProducePersonalizedAdvice() throws {
        let feedback = try #require(HealthFeedback(dto: report(items: [:])))

        #expect(feedback.followUps.isEmpty)
        #expect(feedback.headline == "다시 물어볼 대화 내용이 아직 없어요")
    }

    @Test
    func unrecognizedAndBlankTopicsAreIgnoredAndDuplicatesRemoved() throws {
        let feedback = try #require(HealthFeedback(dto: report(items: [
            "sleep": ["  밤에 자주 깼다고 이야기했어요.  ", "밤에 자주 깼다고 이야기했어요.", " \n"],
            "unknown": ["서버에서 추가한 미지원 항목"]
        ])))

        #expect(feedback.followUps.count == 1)
        #expect(feedback.followUps.first?.summary == "밤에 자주 깼다고 이야기했어요.")
    }

    @Test
    func noAnalysisDoesNotUseStaleConversationItems() {
        #expect(HealthFeedback(dto: report(items: ["sleep": ["이전 대화"]], count: 0)) == nil)
    }

    @Test
    func symptomAndMedicationQuestionsDoNotAssumeTreatmentChanges() throws {
        let feedback = try #require(HealthFeedback(dto: report(items: [
            "symptom": ["몸 상태를 이야기했어요."],
            "medication": ["복약 시간을 이야기했어요."]
        ])))

        #expect(feedback.followUps.first?.question == "최근 통화에서 나눈 몸 상태 이야기는 요즘 어때요?")
        #expect(feedback.followUps.last?.question == "최근 통화에서 나눈 약 이야기에서 더 알려주실 내용이 있어요?")
    }

    private func report(items: [String: [String]], count: Int = 1) -> ReportDTO {
        ReportDTO(
            parentId: "parent", period: "WEEK", from: "2026-09-07", to: "2026-09-13",
            state: "BASELINE_COLLECTING", emptyMessage: nil, disclaimer: "", advisory: nil,
            promotedSignals: [], acuteSignals: [], conversationItems: items,
            repeatObservation: RepeatObservationDTO(count: 0, callsWithRepeat: 0, label: ""),
            acousticTrends: [], recentAcousticHistory: nil, analyzedCallCount: count,
            containsDemoData: false, demoDataNotice: nil
        )
    }
}
