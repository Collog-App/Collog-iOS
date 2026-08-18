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
    private(set) var weekOffset = 0

    var title: String { selectedTabIndex == 0 ? "리포트" : "타임라인" }

    var canGoForward: Bool { weekOffset < 0 }

    init(selectedTabIndex: Int = 1) {
        self.selectedTabIndex = selectedTabIndex
    }

    @discardableResult
    func moveWeek(_ delta: Int) -> Bool {
        guard delta < 0 || canGoForward else { return false }
        weekOffset += delta
        applyWeekHeader()
        return true
    }

    private func applyWeekHeader() {
        let bounds = Self.weekBounds(offset: weekOffset)
        week = TimelineWeek(
            title: Self.weekTitle(for: bounds.start),
            rangeText: APIFormat.shortRange(
                from: APIFormat.isoDate.string(from: bounds.start),
                to: APIFormat.isoDate.string(from: bounds.end)
            ),
            entries: []
        )
        report = WeeklyReport.empty
        isLiveData = false
    }

    func refresh(using environment: AppEnvironment) async {
        let bounds = Self.weekBounds(offset: weekOffset)
        applyWeekHeader()

        guard let parentId = await environment.subjectParentId() else { return }
        isLoading = true
        isLiveData = false
        loadError = nil

        let api = environment.api
        let baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [String: BaselineDTO]()) { $0[$1.metric] = $1 }

        do {
            let dto = try await api.report(
                parentId: parentId,
                date: APIFormat.isoDate.string(from: bounds.anchor)
            )
            let history = dto.recentAcousticHistory ?? dto.acousticTrends
            let trend = history
                .first { $0.metric == "SPEECH_RATE" }
                .flatMap { TrendSeries(trend: $0, baseline: baselines["SPEECH_RATE"]) }

            report = WeeklyReport(dto: dto, trend: trend)
            selectedMember = environment.family.contacts.first?.name
                ?? environment.session.user?.name
                ?? selectedMember
            isLiveData = true
        } catch {
            loadError = error.localizedDescription
        }

        await loadEntries(parentId: parentId, api: api, baselines: baselines, bounds: bounds)
        isLoading = false
    }

    private func loadEntries(
        parentId: String,
        api: CollogAPI,
        baselines: [String: BaselineDTO],
        bounds: (anchor: Date, start: Date, end: Date)
    ) async {
        let calls = try? await api.calls(
            parentId: parentId,
            from: APIFormat.isoDate.string(from: bounds.start),
            to: APIFormat.isoDate.string(from: bounds.end)
        )
        let analyzed = (calls ?? []).filter(\.isAnalyzed).prefix(5)
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
    }

    private static func weekBounds(offset: Int) -> (anchor: Date, start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        let today = calendar.startOfDay(for: Date())
        let anchor = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? anchor

        return (anchor, start, end)
    }

    private static func weekTitle(for start: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: start)
        let week = calendar.component(.weekOfMonth, from: start)
        return "\(month)월 \(week)주"
    }
}
