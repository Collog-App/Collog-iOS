//
//  HomeViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class HomeViewModel {
    private(set) var healthSummary: FamilyHealthSummary = .sample
    private(set) var healthFeedback: HealthFeedback = .sample
    private(set) var lastCallText = "아직 통화 기록이 없어요"
    private(set) var isLoaded = true

    func refresh(
        using environment: AppEnvironment,
        contact: FamilyContact?,
        showsLoading: Bool = false
    ) async {
        if environment.settings.isGuestMode {
            healthSummary = .sample(for: contact)
            healthFeedback = .sample(for: contact)
            lastCallText = contact?.lastCallText.appending("했어요") ?? "최근 통화했어요"
            isLoaded = true
            return
        }

        guard environment.session.isAuthenticated else { return }
        let resolvedId = if let userId = contact?.userId { userId } else { await environment.subjectParentId() }
        guard let parentId = resolvedId else { return }

        if showsLoading { isLoaded = false }
        defer {
            if showsLoading { isLoaded = true }
        }

        let api = environment.api
        await loadLastCall(api: api, parentId: parentId)

        let baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [String: BaselineDTO]()) { $0[$1.metric] = $1 }

        guard let dto = try? await api.report(parentId: parentId) else { return }
        let history = dto.recentAcousticHistory ?? dto.acousticTrends
        guard
            let trend = history
                .first(where: { $0.metric == "SPEECH_RATE" })
                .flatMap({ TrendSeries(trend: $0, baseline: baselines["SPEECH_RATE"]) })
        else { return }

        let signal = dto.promotedSignals.first ?? dto.acuteSignals.first
        healthSummary = FamilyHealthSummary(
            memberName: contact?.name ?? "가족",
            periodText: APIFormat.shortRange(from: dto.from, to: dto.to),
            headline: signal.map { MetricLabel.korean(for: $0.metric) + "에 변화가 보여요" }
                ?? "평소 범위 안에서 지내고 계세요",
            detail: signal?.summaryText ?? signal?.acuteText
                ?? "최근 \(dto.analyzedCallCount)건의 통화를 분석했어요.",
            trend: trend,
            stats: [
                CallStat(label: "분석된 통화", value: "\(dto.analyzedCallCount)", unit: "건", note: nil),
                CallStat(
                    label: "되물으심",
                    value: "\(dto.repeatObservation.count)",
                    unit: "회",
                    note: nil
                )
            ]
        )

        if let advisory = dto.advisory {
            healthFeedback = HealthFeedback(
                title: "건강 피드백",
                headline: advisory,
                tags: ["최근 리포트", APIFormat.shortRange(from: dto.from, to: dto.to)]
            )
        }
    }

    private func loadLastCall(api: CollogAPI, parentId: String) async {
        guard
            let calls = try? await api.calls(parentId: parentId),
            let latest = calls.first
        else { return }

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latest.startedAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        lastCallText = switch days {
        case ..<1: "오늘 통화했어요"
        case 1: "어제 통화했어요"
        case 2: "그저께 통화했어요"
        default: "\(days)일 전에 통화했어요"
        }
    }
}
