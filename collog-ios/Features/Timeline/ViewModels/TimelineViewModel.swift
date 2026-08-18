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

    private(set) var week: TimelineWeek = .sample
    private(set) var report: WeeklyReport = .sample
    private(set) var selectedMember = "어머니"
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var isLiveData = false

    let tabTitles = ["리포트", "타임라인"]

    init(selectedTabIndex: Int = 1) {
        self.selectedTabIndex = selectedTabIndex
    }

    func refresh(using environment: AppEnvironment) async {
        guard let parentId = await environment.subjectParentId() else { return }
        isLoading = true
        loadError = nil

        let api = environment.api
        let baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [String: BaselineDTO]()) { result, item in
                result[item.metric] = item
            }

        do {
            let dto = try await api.report(parentId: parentId)
            let history = dto.recentAcousticHistory ?? dto.acousticTrends
            let trend = history
                .first { $0.metric == "SPEECH_RATE" }
                .flatMap { TrendSeries(trend: $0, baseline: baselines["SPEECH_RATE"]) }

            report = WeeklyReport(dto: dto, trend: trend)
            selectedMember = environment.family.contacts.first?.name
                ?? environment.session.user?.name
                ?? selectedMember
            week = TimelineWeek(
                title: APIFormat.weekTitle(from: dto.from),
                rangeText: APIFormat.shortRange(from: dto.from, to: dto.to),
                entries: week.entries
            )
            isLiveData = true
        } catch {
            loadError = error.localizedDescription
        }

        await loadEntries(parentId: parentId, api: api, baselines: baselines)
        isLoading = false
    }

    private func loadEntries(
        parentId: String,
        api: CollogAPI,
        baselines: [String: BaselineDTO]
    ) async {
        guard let calls = try? await api.calls(parentId: parentId) else { return }
        let analyzed = calls.filter(\.isAnalyzed).prefix(5)
        guard !analyzed.isEmpty else { return }

        var entries: [CallTimelineEntry] = []
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
            entries.append(CallTimelineEntry(bundle: bundle, baselines: baselines))
        }

        week = TimelineWeek(title: week.title, rangeText: week.rangeText, entries: entries)
        isLiveData = true
    }
}
