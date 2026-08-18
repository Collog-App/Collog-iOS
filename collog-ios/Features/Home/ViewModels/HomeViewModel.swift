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

    func refresh(using environment: AppEnvironment) async {
        guard environment.session.isAuthenticated else { return }
        guard let parentId = await environment.subjectParentId() else { return }

        let api = environment.api
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
            memberName: environment.family.contacts.first?.name ?? "가족",
            periodText: "\(dto.from) ~ \(dto.to)",
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
                tags: ["최근 리포트", "\(dto.from) ~ \(dto.to)"]
            )
        }
    }
}
