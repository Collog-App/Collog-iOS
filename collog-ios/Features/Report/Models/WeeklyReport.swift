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
    static let empty = WeeklyReport(
        state: .empty,
        noticeText: nil,
        summaryStats: [],
        changeSignals: [],
        conversationGroups: [],
        repeatObservation: RepeatObservation(countText: "0", perMinuteText: "", caption: ""),
        acousticTrend: .speechRateSample,
        metricTrends: [],
        disclaimer: ""
    )

    static let sample = WeeklyReport(
        state: .ready,
        noticeText: nil,
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
            ConversationGroup(
                category: "증상",
                symbol: "stethoscope",
                items: ["허리가 조금 불편하다고 하셨어요"]
            ),
            ConversationGroup(
                category: "복약",
                symbol: "pills",
                items: ["혈압약은 꾸준히 복용 중이라고 하셨어요"]
            ),
            ConversationGroup(
                category: "활동",
                symbol: "figure.walk",
                items: ["주말에 가벼운 산책을 하셨어요"]
            ),
            ConversationGroup(
                category: "수면",
                symbol: "moon",
                items: ["잠드는 데 오래 걸린다고 하셨어요"]
            )
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
        disclaimer: ""
    )

    static func sample(for relation: String?) -> WeeklyReport {
        guard relation == "FATHER" else { return .sample }
        return WeeklyReport(
            state: .ready,
            noticeText: nil,
            summaryStats: [
                CallStat(label: "분석된 통화", value: "2", unit: "건", note: StatNote(text: "지난주 3건")),
                CallStat(label: "총 통화 시간", value: "27", unit: "분", note: StatNote(text: "지난주 29분"))
            ],
            changeSignals: [
                ChangeSignalItem(
                    metricName: "말씀 속도",
                    summary: "최근 4주 동안 비슷하게 유지되고 있어요.",
                    tone: .steady,
                    isPromoted: true
                ),
                ChangeSignalItem(
                    metricName: "통화 길이",
                    summary: "지난주보다 2분 길어졌어요.",
                    tone: .steady,
                    isPromoted: false
                )
            ],
            conversationGroups: [
                ConversationGroup(
                    category: "활동",
                    symbol: "figure.walk",
                    items: ["아침 산책을 꾸준히 하셨어요"]
                ),
                ConversationGroup(
                    category: "식사",
                    symbol: "fork.knife",
                    items: ["점심으로 국수를 드셨어요"]
                ),
                ConversationGroup(
                    category: "수면",
                    symbol: "moon",
                    items: ["어젯밤 편하게 주무셨다고 하셨어요"]
                )
            ],
            repeatObservation: RepeatObservation(
                countText: "1",
                perMinuteText: "분당 0.1회",
                caption: "대화 중 다시 물어보신 횟수예요"
            ),
            acousticTrend: .speechRateFatherSample,
            metricTrends: [
                MetricTrend(
                    label: "말씀 속도",
                    value: "194",
                    unit: "음절/분",
                    values: [184, 188, 187, 192, 190, 194],
                    shape: .line
                ),
                MetricTrend(
                    label: "되물으심",
                    value: "1",
                    unit: "회",
                    values: [2, 1, 1, 2, 1, 1],
                    shape: .bar
                )
            ],
            disclaimer: ""
        )
    }

    static func sample(for relation: String?, offset: Int) -> WeeklyReport {
        let base = sample(for: relation)
        let distance = abs(offset)
        let isFather = relation == "FATHER"
        let callCount = (isFather ? 2 : 3) + distance % 2
        let totalMinutes = (isFather ? 27 : 32) + (distance * 3) % 13
        let repeatCount = (isFather ? 1 : 3) + distance % 3
        let speechDelta = Double((distance * 3) % 9 - 4)
        let acousticTrend = shiftedTrend(base.acousticTrend, offset: offset, delta: speechDelta)

        return WeeklyReport(
            state: base.state,
            noticeText: base.noticeText,
            summaryStats: [
                CallStat(
                    label: "분석된 통화",
                    value: "\(callCount)",
                    unit: "건",
                    note: StatNote(text: "지난주 \(max(1, callCount - 1 + distance % 3))건")
                ),
                CallStat(
                    label: "총 통화 시간",
                    value: "\(totalMinutes)",
                    unit: "분",
                    note: StatNote(text: "지난주 \(max(18, totalMinutes - 4 + distance % 7))분")
                )
            ],
            changeSignals: sampleSignals(
                base: base.changeSignals,
                relation: relation,
                distance: distance
            ),
            conversationGroups: rotatedGroups(base.conversationGroups, distance: distance),
            repeatObservation: RepeatObservation(
                countText: "\(repeatCount)",
                perMinuteText: String(format: "분당 %.1f회", Double(repeatCount) / Double(callCount * 8)),
                caption: base.repeatObservation.caption
            ),
            acousticTrend: acousticTrend,
            metricTrends: sampleMetricTrends(
                base: base.metricTrends,
                trend: acousticTrend,
                repeatCount: repeatCount,
                distance: distance
            ),
            disclaimer: base.disclaimer
        )
    }

    private static func shiftedTrend(
        _ trend: TrendSeries,
        offset: Int,
        delta: Double
    ) -> TrendSeries {
        let count = trend.points.count
        let points = trend.points.enumerated().map { index, point in
            let pointOffset = offset + index - (count - 1)
            let page = TimelineWeekPage(offset: pointOffset)
            let variation = Double((abs(pointOffset) + index) % 3 - 1)
            return TrendPoint(
                date: TimelineWeekPage.bounds(offset: pointOffset).anchor,
                label: page.title,
                value: point.value + delta + variation
            )
        }
        return TrendSeries(
            metricName: trend.metricName,
            unit: trend.unit,
            points: points,
            normalRange: trend.normalRange
        )
    }

    private static func sampleSignals(
        base: [ChangeSignalItem],
        relation: String?,
        distance: Int
    ) -> [ChangeSignalItem] {
        let motherSummaries = [
            "최근 4주 동안 조금씩 빨라졌어요.",
            "지난주보다 3음절 느려졌어요.",
            "최근 기록이 평소 범위 안에 있어요.",
            "작은 오르내림을 보이며 유지되고 있어요."
        ]
        let fatherSummaries = [
            "최근 4주 동안 비슷하게 유지되고 있어요.",
            "지난주보다 2음절 빨라졌어요.",
            "편안한 속도로 대화하셨어요.",
            "최근 기록 사이 변화가 크지 않아요."
        ]
        let summaries = relation == "FATHER" ? fatherSummaries : motherSummaries
        return base.enumerated().map { index, signal in
            let summary = index == 0
                ? summaries[distance % summaries.count]
                : "지난주와 비슷하게 유지되고 있어요."
            return ChangeSignalItem(
                metricName: signal.metricName,
                summary: summary,
                tone: distance % 3 == 0 ? signal.tone : .steady,
                isPromoted: signal.isPromoted
            )
        }
    }

    private static func rotatedGroups(
        _ groups: [ConversationGroup],
        distance: Int
    ) -> [ConversationGroup] {
        guard !groups.isEmpty else { return [] }
        let pivot = distance % groups.count
        return Array(groups[pivot...] + groups[..<pivot])
    }

    private static func sampleMetricTrends(
        base: [MetricTrend],
        trend: TrendSeries,
        repeatCount: Int,
        distance: Int
    ) -> [MetricTrend] {
        base.enumerated().map { index, metric in
            if index == 0 {
                return MetricTrend(
                    label: metric.label,
                    value: "\(Int(trend.latest?.value.rounded() ?? 0))",
                    unit: metric.unit,
                    values: trend.points.map(\.value),
                    shape: metric.shape
                )
            }

            let values = metric.values.enumerated().map { valueIndex, value in
                max(0, value + Double((distance + valueIndex) % 3 - 1))
            }
            return MetricTrend(
                label: metric.label,
                value: "\(repeatCount)",
                unit: metric.unit,
                values: values,
                shape: metric.shape
            )
        }
    }
}
