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
    private(set) var selectedContactId: String?
    private(set) var selectedRelation: String?
    private(set) var weekOffset = 0
    private(set) var loadError: String?

    @ObservationIgnored private var baselineCache: [String: [String: BaselineDTO]] = [:]
    @ObservationIgnored private var loading: Set<Int> = []
    @ObservationIgnored private var contentGeneration = 0

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

    func selectMember(_ contact: FamilyContact) {
        guard selectedContactId != contact.id else { return }
        selectedContactId = contact.id
        selectedMember = contact.name
        selectedRelation = contact.relation
        weekOffset = 0
        pages.removeAll()
        loading.removeAll()
        contentGeneration += 1
        loadError = nil
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

        guard let context = await loadContext(using: environment) else { return }
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

    func loadPage(_ offset: Int, using environment: AppEnvironment) async {
        resolveSelection(using: environment)
        let generation = contentGeneration

        if environment.settings.isGuestMode {
            loadGuestPage(offset)
            return
        }

        guard offset <= 0, let context = await loadContext(using: environment) else { return }
        guard generation == contentGeneration else { return }
        await load(
            offset,
            parentId: context.parentId,
            api: context.api,
            baselines: context.baselines,
            generation: generation
        )
    }

    private func loadGuestPage(_ offset: Int) {
        guard offset <= 0, pages[offset]?.isLoaded != true else { return }
        var page = TimelineWeekPage(offset: offset)
        page.report = .sample(for: selectedRelation)
        if offset >= -3 {
            page.entries = [.sample(offset: offset, relation: selectedRelation)]
        }
        page.isLoaded = true
        pages[offset] = page
    }

    private func loadContext(
        using environment: AppEnvironment
    ) async -> (parentId: String, api: CollogAPI, baselines: [String: BaselineDTO])? {
        let contact = selectedContact(using: environment)
        let resolvedId = if let userId = contact?.userId { userId } else { await environment.subjectParentId() }
        guard let parentId = resolvedId else { return nil }
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
        let contacts = environment.family.contacts
        return contacts.first { $0.id == selectedContactId } ?? contacts.first
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
            if generation == contentGeneration {
                loadError = error.localizedDescription
            }
        }

        if let entries = await entries(
            parentId: parentId,
            api: api,
            baselines: baselines,
            bounds: bounds
        ) {
            page.entries = entries
        }
        guard generation == contentGeneration else { return }
        page.isLoaded = true
        pages[offset] = page
    }

    private func entries(
        parentId: String,
        api: CollogAPI,
        baselines: [String: BaselineDTO],
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
