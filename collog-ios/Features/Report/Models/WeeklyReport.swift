//
//  WeeklyReport.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum ReportState {
    case ready
    case empty
    case baselineCollecting
}

enum SignalTone {
    case steady
    case watch
}

struct ChangeSignalItem: Identifiable {
    let id = UUID()
    let metricName: String
    let summary: String
    let tone: SignalTone
    let isPromoted: Bool
}

struct ConversationGroup: Identifiable {
    let id = UUID()
    let category: String
    let symbol: String
    let items: [String]
}

struct RepeatObservation {
    let countText: String
    let perMinuteText: String
    let caption: String
}

struct WeeklyReport {
    let state: ReportState
    let noticeText: String?
    let summaryStats: [CallStat]
    let changeSignals: [ChangeSignalItem]
    let conversationGroups: [ConversationGroup]
    let repeatObservation: RepeatObservation
    let acousticTrend: TrendSeries
    let metricTrends: [MetricTrend]
    let disclaimer: String
}

extension WeeklyReport {
    static let sample = WeeklyReport(
        state: .ready,
        noticeText: "시연용 더미 데이터가 포함되어 있어요.",
        summaryStats: [
            CallStat(label: "분석된 통화", value: "3", unit: "건", note: StatNote(text: "지난주 4건")),
            CallStat(label: "총 통화 시간", value: "32", unit: "분", note: StatNote(text: "지난주 41분"))
        ],
        changeSignals: [
            ChangeSignalItem(
                metricName: "말씀 속도",
                summary: "4주 연속 조금씩 빨라지고 있어요. 처음 대비 +8%",
                tone: .watch,
                isPromoted: true
            ),
            ChangeSignalItem(
                metricName: "통화 길이",
                summary: "지난달과 비슷하게 유지되고 있어요.",
                tone: .steady,
                isPromoted: false
            )
        ],
        conversationGroups: [
            ConversationGroup(category: "증상", symbol: "stethoscope", items: ["허리가 조금 불편하다고 하셨어요"]),
            ConversationGroup(category: "복약", symbol: "pills", items: ["혈압약은 꾸준히 복용 중이라고 하셨어요"]),
            ConversationGroup(category: "활동", symbol: "figure.walk", items: ["주말에 가벼운 산책을 하셨어요"]),
            ConversationGroup(category: "수면", symbol: "moon", items: ["잠드는 데 오래 걸린다고 하셨어요"])
        ],
        repeatObservation: RepeatObservation(
            countText: "3",
            perMinuteText: "분당 0.4회",
            caption: "대화 중 다시 물어보신 횟수예요"
        ),
        acousticTrend: .speechRateSample,
        metricTrends: [
            MetricTrend(label: "말씀 속도", value: "208", unit: "음절/분",
                        values: [229, 205, 212, 209, 216, 208], shape: .line),
            MetricTrend(label: "되물으심", value: "3", unit: "회",
                        values: [1, 2, 1, 3, 2, 3], shape: .bar)
        ],
        disclaimer: "이 기록은 의료 진단이 아니에요. 같은 분의 이전 기록과 비교한 관찰값이에요."
    )
}
