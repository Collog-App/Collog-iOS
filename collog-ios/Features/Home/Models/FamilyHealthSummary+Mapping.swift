//
//  FamilyHealthSummary+Mapping.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation

extension FamilyHealthSummary {
    init?(dto: ReportDTO, memberName: String, baseline: BaselineDTO?) {
        guard dto.analyzedCallCount > 0 else { return nil }
        let history = dto.recentAcousticHistory ?? dto.acousticTrends
        let trend = history.first { $0.metric == "SPEECH_RATE" }
            .flatMap { TrendSeries(trend: $0, baseline: baseline) }
        let report = WeeklyReport(dto: dto, trend: trend)
        let signal = dto.promotedSignals.first ?? dto.acuteSignals.first
        let headline: String
        let detail: String
        if let signal {
            headline = MetricLabel.korean(for: signal.metric) + "에 변화가 관찰됐어요"
            detail = signal.summaryText ?? signal.acuteText ?? "통화에서 측정한 값의 변화예요."
        } else if dto.state == "BASELINE_COLLECTING" || baseline?.isReady != true {
            headline = "통화 내용을 먼저 정리했어요"
            detail = "평소와 비교할 음성 기록을 모으고 있어요."
        } else {
            headline = "이번 기간의 통화 기록이에요"
            detail = "분석한 \(dto.analyzedCallCount)건의 통화에서 나눈 이야기를 확인해보세요."
        }
        self.init(
            memberName: memberName,
            periodText: APIFormat.shortRange(from: dto.from, to: dto.to),
            headline: headline,
            detail: detail,
            trend: trend,
            stats: report.summaryStats,
            conversationGroups: report.conversationGroups
        )
    }
}
