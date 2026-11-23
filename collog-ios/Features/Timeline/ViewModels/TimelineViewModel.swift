//
//  TimelineViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class TimelineViewModel {
    var selectedTabIndex: Int

    private(set) var pages: [Int: TimelineWeekPage] = [:]
    private(set) var selectedMember = "가족"
    private(set) var selectedContactId: String?
    private(set) var selectedRelation: String?
    private(set) var weekOffset = 0

    @ObservationIgnored private var baselineCache: [String: [String: BaselineDTO]] = [:]
    @ObservationIgnored private var loading: Set<Int> = []
    @ObservationIgnored private var contentGeneration = 0
    @ObservationIgnored private var choseSelf = false

    static let selfSubjectId = "self"
    /// 한 주에 불러오는 통화 카드 수.
    static let weeklyEntryLimit = 5

    var title: String { selectedTabIndex == 0 ? "리포트" : "타임라인" }

    var canGoForward: Bool { weekOffset < 0 }

    var week: TimelineWeekPage { page(for: weekOffset) }

    var isSelfSelected: Bool { selectedContactId == Self.selfSubjectId }

    init(selectedTabIndex: Int = 1) {
        self.selectedTabIndex = selectedTabIndex
    }

    /// 리포트·타임라인 대상: 가족(지금 순서) 뒤에 「나」. 「나」는 통화 상대·오늘의 질문에는 넣지 않는다.
    func subjects(using environment: AppEnvironment) -> [FamilyContact] {
        let contacts = environment.family.contacts
        guard !environment.settings.isGuestMode, let user = environment.session.user else { return contacts }
        return contacts + [
            FamilyContact(id: Self.selfSubjectId, userId: user.id, name: "나", relation: "", lastCallText: "")
        ]
    }

    func page(for offset: Int) -> TimelineWeekPage {
        pages[offset] ?? TimelineWeekPage(offset: offset)
    }

    func setWeek(_ offset: Int) {
        guard offset <= 0 else { return }
        weekOffset = offset
    }

    func selectMember(_ contact: FamilyContact) {
        guard selectedContactId != contact.id else { return }
        choseSelf = contact.id == Self.selfSubjectId
        selectedContactId = contact.id
        selectedMember = contact.name
        selectedRelation = contact.relation
        weekOffset = 0
        pages.removeAll()
        loading.removeAll()
        contentGeneration += 1
    }

    func refresh(using environment: AppEnvironment, forceReload: Bool = false) async {
        resolveSelection(using: environment)
        let generation = contentGeneration

        if environment.settings.isGuestMode {
            let anchor = weekOffset
            [anchor, anchor - 1, anchor + 1]
                .filter { $0 <= 0 }
                .forEach(loadGuestPage)
            return
        }

        guard let context = await loadContext(using: environment) else {
            guard generation == contentGeneration else { return }
            pages[weekOffset] = TimelineWeekPage(
                offset: weekOffset,
                isLoaded: true,
                reportError: environment.family.loadError,
                timelineError: environment.family.loadError
            )
            return
        }
        guard generation == contentGeneration else { return }

        let anchor = weekOffset
        let offsets = forceReload ? [anchor] : [anchor, anchor - 1, anchor + 1]
        for offset in offsets where offset <= 0 {
            await load(
                offset,
                parentId: context.parentId,
                api: context.api,
                baselines: context.baselines,
                generation: generation,
                forceReload: forceReload
            )
        }
    }

    func loadPage(_ offset: Int, using environment: AppEnvironment, forceReload: Bool = false) async {
        resolveSelection(using: environment)
        let generation = contentGeneration

        if environment.settings.isGuestMode {
            loadGuestPage(offset)
            return
        }

        guard offset <= 0 else { return }
        guard let context = await loadContext(using: environment) else {
            guard generation == contentGeneration else { return }
            pages[offset] = TimelineWeekPage(
                offset: offset,
                isLoaded: true,
                reportError: environment.family.loadError,
                timelineError: environment.family.loadError
            )
            return
        }
        guard generation == contentGeneration else { return }
        await load(
            offset,
            parentId: context.parentId,
            api: context.api,
            baselines: context.baselines,
            generation: generation,
            forceReload: forceReload
        )
    }

    private func loadGuestPage(_ offset: Int) {
        guard offset <= 0, pages[offset]?.isLoaded != true else { return }
        var page = TimelineWeekPage(offset: offset)
        page.report = .sample(for: selectedRelation, offset: offset)
        if selectedTabIndex == 0 {
            let range = Self.lifeRecordRange(offset: offset)
            page.lifeRecord = .sample(end: range.end, today: range.today)
        }
        if offset >= -3 {
            page.entries = [.sample(offset: offset, relation: selectedRelation)]
        }
        page.isLoaded = true
        pages[offset] = page
    }

    private func loadContext(
        using environment: AppEnvironment
    ) async -> (parentId: String, api: CollogAPI, baselines: [String: BaselineDTO])? {
        guard let parentId = selectedContact(using: environment)?.userId else { return nil }
        let api = environment.api

        let baselines: [String: BaselineDTO]
        if let cached = baselineCache[parentId] {
            baselines = cached
        } else {
            let loaded = ((try? await api.baselines(parentId: parentId)) ?? [])
                .filter { $0.kind == "ROLLING" && $0.isReady }
                .reduce(into: [:]) { $0[$1.metric] = $1 }
            baselineCache[parentId] = loaded
            baselines = loaded
        }

        return (parentId, api, baselines)
    }

    private func resolveSelection(using environment: AppEnvironment) {
        guard let contact = selectedContact(using: environment) else {
            if selectedContactId != nil {
                selectedContactId = nil
                selectedRelation = nil
                pages.removeAll()
                loading.removeAll()
                contentGeneration += 1
            }
            selectedMember = environment.session.user?.name ?? selectedMember
            return
        }
        if selectedContactId != contact.id {
            pages.removeAll()
            loading.removeAll()
            contentGeneration += 1
        }
        selectedContactId = contact.id
        selectedMember = contact.name
        selectedRelation = contact.relation
    }

    private func selectedContact(using environment: AppEnvironment) -> FamilyContact? {
        let subjects = subjects(using: environment)
        // 가족이 없어서 「나」로 정해졌으면, 가족이 생긴 뒤에는 첫 가족으로 돌아간다
        let selectedId = isSelfSelected && !choseSelf ? nil : selectedContactId
        return subjects.first { $0.id == selectedId } ?? subjects.first
    }

    private func load(
        _ offset: Int,
        parentId: String,
        api: CollogAPI,
        baselines: [String: BaselineDTO],
        generation: Int,
        forceReload: Bool = false
    ) async {
        guard generation == contentGeneration else { return }
        guard !loading.contains(offset) else { return }
        guard forceReload || pages[offset]?.isLoaded != true else { return }
        loading.insert(offset)
        defer {
            if generation == contentGeneration {
                loading.remove(offset)
            }
        }

        let bounds = TimelineWeekPage.bounds(offset: offset)
        var page = pages[offset] ?? TimelineWeekPage(offset: offset)
        page.reportError = nil
        page.timelineError = nil
        page.isLoaded = false
        pages[offset] = page

        do {
            let dto = try await api.report(
                parentId: parentId,
                date: APIFormat.isoDate.string(from: bounds.anchor)
            )
            let history = dto.recentAcousticHistory ?? dto.acousticTrends
            let trend = history
                .first { $0.metric == "SPEECH_RATE" }
                .flatMap { TrendSeries(trend: $0, baseline: baselines["SPEECH_RATE"]) }

            page.report = WeeklyReport(dto: dto, trend: trend)
        } catch {
            page.reportError = error.localizedDescription
        }

        do {
            let content = try await entries(
                parentId: parentId,
                api: api,
                baselines: baselines,
                bounds: bounds
            )
            page.calls = content.calls
            page.entries = content.entries
        } catch {
            page.timelineError = error.localizedDescription
        }
        if selectedTabIndex == 0 {
            page.lifeRecord = await lifeRecord(parentId: parentId, api: api, offset: offset)
        }
        guard generation == contentGeneration else { return }
        page.isLoaded = true
        pages[offset] = page
    }

    /// 리포트 「생활 기록」: 그 주 끝(이번 주는 오늘)까지 30일을 받아 7일 막대와 최근 측정값을 만든다.
    /// 서버가 받지 않거나(404 등) 공유가 막혔으면 nil 이라 카드를 숨긴다.
    private func lifeRecord(parentId: String, api: CollogAPI, offset: Int) async -> LifeRecord? {
        let range = Self.lifeRecordRange(offset: offset)
        guard let dto = try? await api.parentHealthDaily(
            parentId: parentId,
            from: HealthDailyCalculator.dayString(HealthDailyCalculator.adding(days: -29, to: range.end)),
            to: HealthDailyCalculator.dayString(range.end)
        ) else { return nil }
        return LifeRecord(dto: dto, end: range.end, today: range.today)
    }

    /// 그 주의 마지막 날(서울 날짜, 오늘을 넘지 않음)과 오늘.
    private static func lifeRecordRange(offset: Int) -> (end: Date, today: Date) {
        let today = HealthDailyCalculator.dayOf(Date())
        let weekEnd = APIFormat.isoDate.string(from: TimelineWeekPage.bounds(offset: offset).end)
        return (min(HealthDailyCalculator.day(from: weekEnd) ?? today, today), today)
    }

    private func entries(
        parentId: String,
        api: CollogAPI,
        baselines: [String: BaselineDTO],
        bounds: (anchor: Date, start: Date, end: Date)
    ) async throws -> (calls: [CallSummaryDTO], entries: [CallTimelineEntry]) {
        let calls = try await api.calls(
            parentId: parentId,
            from: APIFormat.isoDate.string(from: bounds.start),
            to: APIFormat.isoDate.string(from: bounds.end)
        )
        // 분석된 통화, 그리고 말씀이 짧아 분석에서 빠졌지만 녹음돼 요약이 있을 수 있는 통화
        let candidates = calls.filter { $0.isAnalyzed || ($0.isAnalysisExcluded && $0.recorded) }

        var result: [CallTimelineEntry] = []
        var excludedLookups = 0
        for call in candidates {
            if result.count == Self.weeklyEntryLimit { break }
            guard call.isAnalyzed else {
                // 분석에서 빠진 통화는 요약이 있을 때만 보인다. 음성 수치는 없어 부르지 않고, 확인도 한 주에 다섯 번까지만 한다
                guard excludedLookups < Self.weeklyEntryLimit else { continue }
                excludedLookups += 1
                if let extraction = try? await api.extraction(callId: call.callId),
                   CallTimelineEntry.summaryText(extraction.summary) != nil {
                    let bundle = CallAnalysisBundle(call: call, features: nil, extraction: extraction, transcript: nil)
                    result.append(CallTimelineEntry(bundle: bundle, baselines: baselines))
                }
                continue
            }
            async let features = try? api.acousticFeatures(callId: call.callId)
            async let extraction = try? api.extraction(callId: call.callId)
            async let transcript = try? api.transcript(callId: call.callId)

            let bundle = await CallAnalysisBundle(
                call: call,
                features: features,
                extraction: extraction,
                transcript: transcript
            )
            result.append(CallTimelineEntry(bundle: bundle, baselines: baselines))
        }

        return (calls, result)
    }
}
