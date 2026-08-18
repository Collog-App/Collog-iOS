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

struct TimelineWeek {
    let title: String
    let rangeText: String
    let entries: [CallTimelineEntry]
}

extension CallTimelineEntry {
    static let sample = CallTimelineEntry(
        dateText: "8월 14일 금요일",
        durationText: "14분 27초",
        summaryStats: CallStat.samples,
        story: "수면이 얕고 자주 깬다고 하셨으며\n혈압약은 꾸준히 복용 중이라고 하셨어요.",
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
            RangeGauge(label: "말 사이 쉼", normalRange: 0.1...0.6, marker: 0.72, caption: "평소보다 길어짐"),
            RangeGauge(label: "목소리 높낮이", normalRange: 0.15...0.7, marker: 0.45, caption: "평소 범위 안")
        ],
        counts: [
            CallStat(label: "기침", value: "4", unit: "회", note: StatNote(text: "평소 2회")),
            CallStat(label: "되물으심", value: "2", unit: "회", note: StatNote(text: "평소 1회")),
            CallStat(label: "웃음", value: "6", unit: "회", note: StatNote(text: "평소 6회"))
        ]
    )
}

extension TimelineWeek {
    static let sample = TimelineWeek(
        title: "8월 3주",
        rangeText: "8/10 – 8/16",
        entries: [.sample]
    )
}
