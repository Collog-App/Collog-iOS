//
//  FamilyHealthSummary.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct FamilyHealthSummary {
    let memberName: String
    let periodText: String
    let headline: String
    let detail: String
    let trend: TrendSeries
    let stats: [CallStat]
}

struct HealthFeedback {
    let title: String
    let headline: String
    let tags: [String]
}

extension FamilyHealthSummary {
    static let sample = FamilyHealthSummary(
        memberName: "어머니",
        periodText: "최근 6주",
        headline: "말씀 속도가 평소 범위 안이에요",
        detail: "6주 동안 큰 변화 없이 유지되고 있어요.",
        trend: .speechRateSample,
        stats: CallStat.samples
    )
}

extension HealthFeedback {
    static let sample = HealthFeedback(
        title: "건강 피드백",
        headline: "인지 장애 우려",
        tags: ["최근 기록", "3일 전 통화"]
    )
}
