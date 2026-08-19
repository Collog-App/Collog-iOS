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
    private(set) var selectedMember = "어머니"
    private(set) var weekOffset = 0
    private(set) var loadError: String?

    @ObservationIgnored private var baselines: [String: BaselineDTO] = [:]
    @ObservationIgnored private var loading: Set<Int> = []

    var title: String { selectedTabIndex == 0 ? "리포트" : "타임라인" }

    var canGoForward: Bool { weekOffset < 0 }

    var week: TimelineWeekPage { page(for: weekOffset) }

    init(selectedTabIndex: Int = 1) {
        self.selectedTabIndex = selectedTabIndex
    }

    func page(for offset: Int) -> TimelineWeekPage {
        pages[offset] ?? TimelineWeekPage(offset: offset)
    }

    func setWeek(_ offset: Int) {
        guard offset <= 0 else { return }
        weekOffset = offset
    }

    func refresh(using environment: AppEnvironment, forceReload: Bool = false) async {
        guard let context = await loadContext(using: environment) else { return }

        let anchor = weekOffset
        let offsets = forceReload ? [anchor] : [anchor, anchor - 1, anchor + 1]
        for offset in offsets where offset <= 0 {
            await load(
                offset,
                parentId: context.parentId,
                api: context.api,
                forceReload: forceReload
            )
        }
    }

    func loadPage(_ offset: Int, using environment: AppEnvironment) async {
        guard offset <= 0, let context = await loadContext(using: environment) else { return }
        await load(offset, parentId: context.parentId, api: context.api)
    }

    private func loadContext(using environment: AppEnvironment) async -> (parentId: String, api: CollogAPI)? {
        guard let parentId = await environment.subjectParentId() else { return nil }
        let api = environment.api

        if baselines.isEmpty {
            baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
                .filter { $0.kind == "ROLLING" && $0.isReady }
                .reduce(into: [:]) { $0[$1.metric] = $1 }
        }

        selectedMember = environment.family.contacts.first?.name
            ?? environment.session.user?.name
            ?? selectedMember
        return (parentId, api)
    }

    private func load(
        _ offset: Int,
        parentId: String,
        api: CollogAPI,
        forceReload: Bool = false
    ) async {
        guard !loading.contains(offset) else { return }
        guard forceReload || pages[offset]?.isLoaded != true else { return }
        loading.insert(offset)
        defer { loading.remove(offset) }

        let bounds = TimelineWeekPage.bounds(offset: offset)
        var page = pages[offset] ?? TimelineWeekPage(offset: offset)

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
            loadError = error.localizedDescription
        }

        if let entries = await entries(parentId: parentId, api: api, bounds: bounds) {
            page.entries = entries
        }
        page.isLoaded = true
        pages[offset] = page
    }

    private func entries(
        parentId: String,
        api: CollogAPI,
        bounds: (anchor: Date, start: Date, end: Date)
    ) async -> [CallTimelineEntry]? {
        guard let calls = try? await api.calls(
            parentId: parentId,
            from: APIFormat.isoDate.string(from: bounds.start),
            to: APIFormat.isoDate.string(from: bounds.end)
        ) else { return nil }
        let analyzed = calls.filter(\.isAnalyzed).prefix(5)
        guard !analyzed.isEmpty else { return [] }

        var result: [CallTimelineEntry] = []
        for call in analyzed {
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

        return result
    }
}
