//
//  CallSummaryTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 통화 요약(extraction `summary`): 타임라인 카드 글 첫머리와 통화 분석 화면 맨 위에 보인다.
/// 말씀이 짧아 분석에서 빠진 통화(ANALYSIS_EXCLUDED)도 요약이 있으면 타임라인에 나온다.
@MainActor
struct CallSummaryTests {
    private let summary = "저녁으로 된장찌개를 드셨고 주말에 손주가 온다고 하셨어요."

    // MARK: - 읽기

    @Test
    func extractionDecodesOptionalSummary() async throws {
        let cases: [(body: String, expected: String?)] = [
            (#"{"callId":"c1","parseStatus":"OK","facts":[],"summary":"요약"}"#, "요약"),
            (#"{"callId":"c1","parseStatus":"EXCLUDED","summary":"요약","safetyNotice":null}"#, "요약"),
            (#"{"callId":"c1","parseStatus":"OK","facts":[],"summary":null}"#, nil),
            (#"{"callId":"c1","parseStatus":"OK","symptom":"허리","facts":[]}"#, nil)
        ]
        for item in cases {
            let fixture = try TestEnvironment()
            defer { fixture.cleanUp() }
            fixture.respond = { _ in (200, item.body) }
            let extraction = try await fixture.environment.api.extraction(callId: "c1")
            #expect(extraction.summary == item.expected)
        }
    }

    @Test
    func blankSummaryCountsAsMissing() {
        #expect(CallTimelineEntry.summaryText(nil) == nil)
        #expect(CallTimelineEntry.summaryText("") == nil)
        #expect(CallTimelineEntry.summaryText(" \n ") == nil)
        #expect(CallTimelineEntry.summaryText("  요약이에요. \n") == "요약이에요.")
    }

    // MARK: - 카드 글

    @Test
    func timelineStoryShowsSummaryFirstThenHealthLines() {
        let card = entry(extraction: extraction(summary: summary, symptom: "허리가 아프다고 하셨어요.", sleep: "잘 주무셨어요."))
        #expect(card.story == "\(summary)\n허리가 아프다고 하셨어요.\n잘 주무셨어요.")
        #expect(card.summary == summary)
        #expect(card.analysisNote == nil)
    }

    @Test
    func summaryAloneReplacesTheNoHealthStoryLine() {
        #expect(entry(extraction: extraction(summary: summary)).story == summary)
    }

    @Test
    func storyWithoutSummaryStaysAsBefore() {
        let withLines = entry(extraction: extraction(summary: nil, symptom: "허리", medication: "혈압약"))
        #expect(withLines.story == "허리\n혈압약")
        #expect(withLines.summary == nil)
        #expect(entry(extraction: extraction(summary: "  ")).story == "이번 통화에서는 기록된 건강 이야기가 없었어요.")
        #expect(entry(extraction: nil).story == "아직 정리된 대화 항목이 없어요.")
    }

    @Test
    func analysisScreenKeepsSummaryOutOfTheCardText() {
        let withHealthLine = entry(extraction: extraction(summary: summary, symptom: "허리"), summaryInStory: false)
        #expect(withHealthLine.story == "허리")
        #expect(withHealthLine.summary == summary)
        let summaryOnly = entry(extraction: extraction(summary: summary), summaryInStory: false)
        #expect(summaryOnly.story == "이번 통화에서는 기록된 건강 이야기가 없었어요.")
        #expect(summaryOnly.summary == summary)
    }

    @Test
    func excludedCallShowsSummaryWithShortSpeechNoteAndNoVoiceNumbers() {
        let card = entry(state: "ANALYSIS_EXCLUDED", extraction: extraction(status: "EXCLUDED", summary: summary))
        #expect(card.story == summary)
        #expect(card.analysisNote == "말씀이 짧아 목소리 분석은 하지 않았어요.")
        #expect(card.summaryStats.map(\.label) == ["통화 길이"])
        #expect(card.summaryStats.first?.value == "2")
        #expect(card.summaryStats.first?.unit == "분")
        #expect(card.gauges.isEmpty)
        #expect(card.counts.isEmpty)
        #expect(card.keywords.isEmpty)
    }

    @Test(arguments: [(45, "45", "초"), (0, "0", "초"), (59, "59", "초"), (60, "1", "분"), (320, "5", "분")])
    func callUnderAMinuteShowsSecondsInsteadOfZeroMinutes(durationSec: Int, value: String, unit: String) {
        let card = entry(
            state: "ANALYSIS_EXCLUDED", extraction: extraction(status: "EXCLUDED", summary: summary),
            durationSec: durationSec
        )
        #expect(card.summaryStats.first?.value == value)
        #expect(card.summaryStats.first?.unit == unit)
    }

    // MARK: - 타임라인

    @Test
    func timelineIncludesExcludedCallsOnlyWhenTheyHaveSummary() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveTimeline(
            fixture,
            calls: [
                call("analyzed", state: "ANALYZED"),
                call("short", state: "ANALYSIS_EXCLUDED"),
                call("silent", state: "ANALYSIS_EXCLUDED"),
                call("blank", state: "ANALYSIS_EXCLUDED"),
                call("unrecorded", state: "ANALYSIS_EXCLUDED", recorded: false),
                call("failed", state: "ANALYSIS_FAILED")
            ],
            extractions: [
                "analyzed": #"{"callId":"analyzed","parseStatus":"OK","symptom":"허리","summary":"분석된 통화 요약"}"#,
                "short": #"{"callId":"short","parseStatus":"EXCLUDED","summary":"짧은 통화 요약"}"#,
                "blank": #"{"callId":"blank","parseStatus":"EXCLUDED","summary":"  "}"#
            ]
        )
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        let page = model.page(for: 0)
        #expect(page.timelineError == nil)
        #expect(page.entries.map(\.story) == ["분석된 통화 요약\n허리", "짧은 통화 요약"])
        #expect(page.entries.map(\.analysisNote) == [nil, CallTimelineEntry.excludedNote])
        #expect(page.calls.count == 6)
        // 분석에서 빠진 통화는 요약만 확인한다. 녹음하지 않은 통화는 확인할 것이 없다.
        #expect(!fixture.paths.contains("/v1/calls/short/acoustic-features"))
        #expect(!fixture.paths.contains("/v1/calls/short/transcript"))
        #expect(!fixture.paths.contains { $0.hasPrefix("/v1/calls/unrecorded/") })
        #expect(!fixture.paths.contains { $0.hasPrefix("/v1/calls/failed/") })
    }

    @Test
    func weeklyLimitCountsCardsAndUnsummarizedCallsDoNotPushAnalyzedOnesOut() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let excluded = (1...6).map { "silent\($0)" }
        let analyzed = (1...7).map { "analyzed\($0)" }
        serveTimeline(
            fixture,
            calls: excluded.map { call($0, state: "ANALYSIS_EXCLUDED") } + analyzed.map { call($0, state: "ANALYZED") },
            extractions: Dictionary(uniqueKeysWithValues: analyzed.map {
                ($0, #"{"callId":"\#($0)","parseStatus":"OK","summary":"\#($0)"}"#)
            })
        )
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        #expect(TimelineViewModel.weeklyEntryLimit == 5)
        #expect(model.page(for: 0).entries.map(\.story) == Array(analyzed.prefix(5)))
        // 분석에서 빠진 통화는 한꺼번에 묻기 때문에 순서는 정해져 있지 않다
        let lookups = Set(fixture.paths.filter { $0.hasSuffix("/extraction") })
        #expect(lookups == Set((excluded.prefix(5) + analyzed.prefix(5)).map { "/v1/calls/\($0)/extraction" }))
    }

    @Test
    func summariesAreOnlyLookedUpForCallsITookPartIn() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        // 어머니가 다른 가족과 한 통화의 분석 결과는 서버가 막는다(403). 묻지 않고, 확인 횟수도 쓰지 않는다.
        let others = (1...6).map { "sibling\($0)" }
        let mine = ["mine1", "mine2"]
        serveTimeline(
            fixture,
            calls: others.map { call($0, state: "ANALYSIS_EXCLUDED", childId: "sibling") }
                + mine.map { call($0, state: "ANALYSIS_EXCLUDED") }
                + [call("unknown", state: "ANALYSIS_EXCLUDED", childId: nil)],
            extractions: Dictionary(uniqueKeysWithValues: (others + mine + ["unknown"]).map {
                ($0, #"{"callId":"\#($0)","parseStatus":"EXCLUDED","summary":"\#($0)"}"#)
            })
        )
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        #expect(model.page(for: 0).entries.map(\.story) == mine)
        let lookups = Set(fixture.paths.filter { $0.hasSuffix("/extraction") })
        #expect(lookups == Set(mine.map { "/v1/calls/\($0)/extraction" }))
    }

    @Test
    func ownTimelineLooksUpEveryShortCallOfMine() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        serveTimeline(
            fixture,
            subject: "me",
            calls: [call("received", state: "ANALYSIS_EXCLUDED", parentId: "me", childId: "mom")],
            extractions: ["received": #"{"callId":"received","parseStatus":"EXCLUDED","summary":"내가 받은 짧은 통화"}"#]
        )
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        model.selectMember(try #require(model.subjects(using: fixture.environment).last))
        await model.loadPage(0, using: fixture.environment)

        #expect(model.isSelfSelected)
        #expect(model.page(for: 0).entries.map(\.story) == ["내가 받은 짧은 통화"])
    }

    @Test
    func callInvolvesOnlyItsTwoParticipants() {
        let call = CallSummaryDTO(
            callId: "c1", parentId: "mom", state: "ANALYZED", timeSlot: nil,
            startedAt: Date(), endedAt: nil, durationSec: nil, recorded: true, parentSpeechSec: nil,
            childId: "me"
        )
        #expect(call.involves("mom"))
        #expect(call.involves("me"))
        #expect(!call.involves("sibling"))
        #expect(!call.involves(nil))
    }

    @Test
    func summarizedExcludedCallsShareTheWeeklyLimit() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let excluded = (1...3).map { "short\($0)" }
        let analyzed = (1...4).map { "analyzed\($0)" }
        serveTimeline(
            fixture,
            calls: excluded.map { call($0, state: "ANALYSIS_EXCLUDED") } + analyzed.map { call($0, state: "ANALYZED") },
            extractions: Dictionary(uniqueKeysWithValues: (excluded + analyzed).map {
                ($0, #"{"callId":"\#($0)","parseStatus":"OK","summary":"\#($0)"}"#)
            })
        )
        await fixture.environment.family.refresh(using: fixture.environment)
        let model = TimelineViewModel()
        await model.loadPage(0, using: fixture.environment)

        #expect(model.page(for: 0).entries.map(\.story) == excluded + Array(analyzed.prefix(2)))
    }

    // MARK: - 통화 분석 화면

    @Test
    func analyzedCallCarriesSummaryForTheTopBlock() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serveCall(
            fixture, state: "ANALYZED",
            extraction: (200, #"{"callId":"c1","parseStatus":"OK","symptom":"허리","summary":"\#(summary)"}"#)
        )
        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .ready(entry) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(entry.summary == summary)
        #expect(entry.story == "허리")
    }

    @Test
    func excludedCallShowsSummaryAboveTheExcludedMessage() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serveCall(
            fixture, state: "ANALYSIS_EXCLUDED",
            extraction: (200, #"{"callId":"c1","parseStatus":"EXCLUDED","summary":"\#(summary)"}"#)
        )
        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .unavailable(title, _, safetyNotice, shownSummary) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(title == "분석 대상에서 제외된 통화예요.")
        #expect(safetyNotice == nil)
        #expect(shownSummary == summary)
    }

    @Test(arguments: [
        (200, #"{"callId":"c1","parseStatus":"EXCLUDED","summary":" "}"#),
        (200, #"{"callId":"c1","parseStatus":"EXCLUDED"}"#),
        (404, #"{"detail":"추출 결과가 아직 없습니다"}"#)
    ])
    func excludedCallWithoutSummaryShowsNoSummaryBlock(status: Int, body: String) async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        serveCall(fixture, state: "ANALYSIS_EXCLUDED", extraction: (status, body))
        let model = CallAnalysisViewModel(callId: "c1")
        await model.load(using: fixture.environment)

        guard case let .unavailable(_, _, _, shownSummary) = model.state else {
            Issue.record("unexpected state \(model.state)")
            return
        }
        #expect(shownSummary == nil)
    }

    // MARK: - Fixtures

    private func extraction(
        status: String = "OK", summary: String?, symptom: String? = nil, medication: String? = nil, sleep: String? = nil
    ) -> ExtractionDTO {
        ExtractionDTO(
            callId: "c1", parseStatus: status, symptom: symptom, medication: medication, activity: nil, sleep: sleep,
            summary: summary
        )
    }

    private func entry(
        state: String = "ANALYZED", extraction: ExtractionDTO?, summaryInStory: Bool = true, durationSec: Int = 120
    ) -> CallTimelineEntry {
        let call = CallSummaryDTO(
            callId: "c1", parentId: "mom", state: state, timeSlot: nil,
            startedAt: Date(), endedAt: Date(), durationSec: durationSec, recorded: true, parentSpeechSec: nil
        )
        return CallTimelineEntry(
            bundle: CallAnalysisBundle(call: call, features: nil, extraction: extraction, transcript: nil),
            baselines: [:],
            summaryInStory: summaryInStory
        )
    }

    /// 기본은 어머니(mom)와 내가(me) 한 통화.
    private func call(
        _ id: String, state: String, recorded: Bool = true, parentId: String = "mom", childId: String? = "me"
    ) -> String {
        """
        {"callId":"\(id)","parentId":"\(parentId)","childId":\(childId.map { "\"\($0)\"" } ?? "null"),
         "state":"\(state)","timeSlot":null,
         "startedAt":"2026-11-05T03:00:00Z","endedAt":"2026-11-05T03:02:00Z","durationSec":120,
         "recorded":\(recorded),"parentSpeechSec":12}
        """
    }

    /// 한 사람(기본은 가족 mom)의 타임라인 한 주. 준비하지 않은 extraction·음성 수치는 404.
    private func serveTimeline(
        _ fixture: TestEnvironment, subject: String = "mom", calls: [String], extractions: [String: String]
    ) {
        let callsBody = "{\"calls\":[\(calls.joined(separator: ","))]}"
        fixture.respond = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/members") {
                return (200, """
                {"members":[{"memberId":"mom","userId":"mom","name":"mom","relation":"MOTHER","status":"ACTIVE"}]}
                """)
            }
            if path.hasSuffix("/daily-questions") { return (200, #"{"source":"fixture","questions":[]}"#) }
            if path.hasSuffix("/baseline") { return (200, #"{"baselines":[]}"#) }
            if path == "/v1/parents/\(subject)/calls" { return (200, callsBody) }
            let parts = path.split(separator: "/").map(String.init)
            if parts.count == 4, parts[1] == "calls", parts[3] == "extraction", let body = extractions[parts[2]] {
                return (200, body)
            }
            return (404, #"{"detail":"없음"}"#)
        }
    }

    private func serveCall(_ fixture: TestEnvironment, state: String, extraction: (Int, String)) {
        let callBody = call("c1", state: state)
        fixture.respond = { request in
            switch request.url?.path ?? "" {
            case "/v1/calls/c1": (200, callBody)
            case "/v1/calls/c1/extraction": extraction
            default: (404, #"{"detail":"없음"}"#)
            }
        }
    }
}
