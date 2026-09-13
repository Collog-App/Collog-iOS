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
    let trend: TrendSeries?
    let stats: [CallStat]
    var conversationGroups: [ConversationGroup] = []
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

    static func sample(for contact: FamilyContact?) -> FamilyHealthSummary {
        guard contact?.relation == "FATHER" else { return .sample }
        return FamilyHealthSummary(
            memberName: contact?.name ?? "아버지",
            periodText: "최근 6주",
            headline: "말씀 속도가 편안하게 유지되고 있어요",
            detail: "최근 기록에서 작은 변화만 보여요.",
            trend: .speechRateFatherSample,
            stats: [
                CallStat(label: "통화 길이", value: "11", unit: "분", note: StatNote(text: "평소 10분")),
                CallStat(
                    label: "말씀 속도",
                    value: "194",
                    unit: "음절/분",
                    note: StatNote(text: "2.11%", trend: .up)
                )
            ]
        )
    }
}
