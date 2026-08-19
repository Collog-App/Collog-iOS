//
//  CallTimelineEntry.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct CallTimelineEntry: Identifiable {
    let id = UUID()
    let dateText: String
    let durationText: String
    let summaryStats: [CallStat]
    let story: String
    let keywords: [KeywordMark]
    let gauges: [RangeGauge]
    let counts: [CallStat]
}

extension CallTimelineEntry {
    static let sample = CallTimelineEntry(
        dateText: "8월 14일 금요일",
        durationText: "14분 27초",
        summaryStats: CallStat.samples,
        story: "수면이 얕고 자주 깬다고 하셨으며\n"
            + "혈압약은 꾸준히 복용 중이라고 하셨어요.",
        keywords: [
            KeywordMark(position: 0.08, tone: .positive, label: nil),
            KeywordMark(position: 0.22, tone: .positive, label: "수면"),
            KeywordMark(position: 0.34, tone: .caution, label: nil),
            KeywordMark(position: 0.41, tone: .concern, label: "허리 통증"),
            KeywordMark(position: 0.58, tone: .positive, label: nil),
            KeywordMark(position: 0.66, tone: .neutral, label: "혈압약"),
            KeywordMark(position: 0.84, tone: .neutral, label: nil)
        ],
        gauges: [
            RangeGauge(
                label: "말 사이 쉼",
                normalRange: 0.1...0.6,
                marker: 0.72,
                caption: "평소보다 길어짐"
            ),
            RangeGauge(
                label: "목소리 높낮이",
                normalRange: 0.15...0.7,
                marker: 0.45,
                caption: "평소 범위 안"
            )
        ],
        counts: [
            CallStat(label: "기침", value: "4", unit: "회", note: StatNote(text: "평소 2회")),
            CallStat(label: "되물으심", value: "2", unit: "회", note: StatNote(text: "평소 1회")),
            CallStat(label: "웃음", value: "6", unit: "회", note: StatNote(text: "평소 6회"))
        ]
    )

    static func sample(offset: Int, relation: String? = nil) -> CallTimelineEntry {
        let base = relation == "FATHER" ? fatherSample : sample
        let distance = abs(offset)
        let variant = distance % 4
        let bounds = TimelineWeekPage.bounds(offset: offset)
        let date = TimelineWeekPage.calendar.date(
            byAdding: .day,
            value: 1 + variant,
            to: bounds.start
        ) ?? bounds.start
        let isFather = relation == "FATHER"
        let duration = (isFather ? 11 : 14) + (distance * 2) % 5
        let speechRate = (isFather ? 194 : 210) + (distance * 3) % 9 - 4
        let markerShift = Double(variant) * 0.025

        return CallTimelineEntry(
            dateText: APIFormat.longDate.string(from: date),
            durationText: "\(duration)분 \(8 + variant * 11)초",
            summaryStats: [
                CallStat(
                    label: "통화 길이",
                    value: "\(duration)",
                    unit: "분",
                    note: StatNote(text: isFather ? "평소 10분" : "평소 12분")
                ),
                CallStat(
                    label: "말씀 속도",
                    value: "\(speechRate)",
                    unit: "음절/분",
                    note: StatNote(text: isFather ? "평소 190" : "평소 208")
                )
            ],
            story: sampleStory(relation: relation, variant: variant),
            keywords: shiftedKeywords(base.keywords, variant: variant),
            gauges: [
                RangeGauge(
                    label: "말 사이 쉼",
                    normalRange: base.gauges[0].normalRange,
                    marker: min(base.gauges[0].marker - markerShift, 0.92),
                    caption: variant == 0 && !isFather ? "평소보다 길어짐" : "평소 범위 안"
                ),
                RangeGauge(
                    label: "목소리 높낮이",
                    normalRange: base.gauges[1].normalRange,
                    marker: min(base.gauges[1].marker + markerShift, 0.9),
                    caption: "평소 범위 안"
                )
            ],
            counts: sampleCounts(isFather: isFather, distance: distance)
        )
    }

    private static func sampleStory(relation: String?, variant: Int) -> String {
        let motherStories = [
            "수면이 얕고 자주 깬다고 하셨으며\n혈압약은 꾸준히 복용 중이라고 하셨어요.",
            "오전에 장을 보고 오셨고\n저녁에는 일찍 쉬실 예정이라고 하셨어요.",
            "점심 식사를 맛있게 드셨고\n주말에 가까운 공원에 다녀오셨어요.",
            "어젯밤 편하게 주무셨고\n오늘은 집에서 쉬고 계셨어요."
        ]
        let fatherStories = [
            "아침 산책을 다녀오셨고\n점심으로 국수를 드셨다고 하셨어요.",
            "친구와 바둑을 두셨고\n저녁 약도 챙겨 드셨다고 하셨어요.",
            "오전에 병원에 다녀오셨고\n검사 결과는 괜찮다고 하셨어요.",
            "주말에 텃밭을 살펴보셨고\n평소보다 일찍 주무셨다고 하셨어요."
        ]
        return relation == "FATHER" ? fatherStories[variant] : motherStories[variant]
    }

    private static func shiftedKeywords(_ keywords: [KeywordMark], variant: Int) -> [KeywordMark] {
        let shift = Double(variant) * 0.018
        return keywords.map { keyword in
            KeywordMark(
                position: min(max(keyword.position + shift, 0.04), 0.96),
                tone: keyword.tone,
                label: keyword.label
            )
        }
    }

    private static func sampleCounts(isFather: Bool, distance: Int) -> [CallStat] {
        let cough = (isFather ? 1 : 4) + distance % 3
        let repeatCount = (isFather ? 1 : 2) + distance % 2
        let laugh = (isFather ? 8 : 6) - distance % 3
        return [
            CallStat(label: "기침", value: "\(cough)", unit: "회", note: StatNote(text: "평소 2회")),
            CallStat(label: "되물으심", value: "\(repeatCount)", unit: "회", note: StatNote(text: "평소 1회")),
            CallStat(label: "웃음", value: "\(laugh)", unit: "회", note: StatNote(text: "평소 6회"))
        ]
    }

    private static let fatherSample = CallTimelineEntry(
        dateText: "8월 15일 토요일",
        durationText: "11분 08초",
        summaryStats: [
            CallStat(label: "통화 길이", value: "11", unit: "분", note: StatNote(text: "평소 10분")),
            CallStat(label: "말씀 속도", value: "194", unit: "음절/분", note: StatNote(text: "평소 190"))
        ],
        story: "아침 산책을 다녀오셨고\n점심으로 국수를 드셨다고 하셨어요.",
        keywords: [
            KeywordMark(position: 0.12, tone: .positive, label: nil),
            KeywordMark(position: 0.28, tone: .positive, label: "산책"),
            KeywordMark(position: 0.47, tone: .neutral, label: nil),
            KeywordMark(position: 0.63, tone: .positive, label: "점심"),
            KeywordMark(position: 0.82, tone: .neutral, label: nil)
        ],
        gauges: [
            RangeGauge(
                label: "말 사이 쉼",
                normalRange: 0.15...0.72,
                marker: 0.48,
                caption: "평소 범위 안"
            ),
            RangeGauge(
                label: "목소리 높낮이",
                normalRange: 0.18...0.76,
                marker: 0.53,
                caption: "평소 범위 안"
            )
        ],
        counts: [
            CallStat(label: "기침", value: "1", unit: "회", note: StatNote(text: "평소 2회")),
            CallStat(label: "되물으심", value: "1", unit: "회", note: StatNote(text: "평소 1회")),
            CallStat(label: "웃음", value: "8", unit: "회", note: StatNote(text: "평소 6회"))
        ]
    )
}
