//
//  CallTimelineEntry+Mapping.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct CallAnalysisBundle {
    let call: CallSummaryDTO
    let features: AcousticFeaturesDTO?
    let extraction: ExtractionDTO?
    let transcript: TranscriptDTO?
}

extension CallTimelineEntry {
    init(bundle: CallAnalysisBundle, baselines: [String: BaselineDTO]) {
        let features = bundle.features?.features ?? []
        let durationSec = bundle.call.durationSec ?? 0

        let speechRate = features.first { $0.metric == "SPEECH_RATE" && $0.isMeasured }
        let cough = features.first { $0.metric == "COUGH_EVENTS" && $0.isMeasured }
        let repeatCount = bundle.transcript?.repeatRequestCount ?? 0

        var stats: [CallStat] = [
            CallStat(
                label: "통화 길이",
                value: "\(max(durationSec / 60, 0))",
                unit: "분",
                note: StatNote(text: APIFormat.duration(seconds: durationSec))
            )
        ]
        if let speechRate, let value = speechRate.value {
            stats.append(
                CallStat(
                    label: "말씀 속도",
                    value: "\(Int(value.rounded()))",
                    unit: speechRate.unit,
                    note: Self.note(value: value, baseline: baselines["SPEECH_RATE"])
                )
            )
        }

        var counts: [CallStat] = [
            CallStat(label: "되물으심", value: "\(repeatCount)", unit: "회", note: nil)
        ]
        if let cough, let value = cough.value {
            counts.insert(
                CallStat(label: "기침", value: "\(Int(value.rounded()))", unit: cough.unit, note: nil),
                at: 0
            )
        }

        self.init(
            dateText: APIFormat.longDate.string(from: bundle.call.startedAt),
            durationText: APIFormat.duration(seconds: durationSec),
            summaryStats: stats,
            story: Self.story(from: bundle.extraction),
            keywords: Self.keywords(from: bundle.transcript, durationSec: durationSec),
            gauges: Self.gauges(features: features, baselines: baselines),
            counts: counts
        )
    }

    private static func note(value: Double, baseline: BaselineDTO?) -> StatNote? {
        guard let baseline, baseline.isReady, let median = baseline.median, median != 0 else { return nil }
        let delta = (value - median) / abs(median) * 100
        let trend: StatTrend = abs(delta) < 1 ? .flat : (delta > 0 ? .up : .down)
        return StatNote(text: String(format: "평소 대비 %+.0f%%", delta), trend: trend)
    }

    private static func story(from extraction: ExtractionDTO?) -> String {
        guard let extraction else { return "아직 정리된 대화 항목이 없어요." }
        let lines = [extraction.symptom, extraction.medication, extraction.activity, extraction.sleep]
            .compactMap { $0 }
        return lines.isEmpty ? "이번 통화에서는 기록된 건강 이야기가 없었어요." : lines.joined(separator: "\n")
    }

    private static func keywords(from transcript: TranscriptDTO?, durationSec: Int) -> [KeywordMark] {
        guard let transcript, durationSec > 0 else { return [] }
        let total = Double(durationSec * 1000)
        return transcript.repeatEvents.prefix(8).enumerated().map { index, event in
            KeywordMark(
                position: min(max(Double(event.startMs) / total, 0), 1),
                tone: .caution,
                label: index < 2 ? "되물음" : nil
            )
        }
    }

    private static func gauges(
        features: [AcousticFeatureDTO],
        baselines: [String: BaselineDTO]
    ) -> [RangeGauge] {
        ["PAUSE_RATIO", "F0_VARIATION"].compactMap { metric in
            guard
                let feature = features.first(where: { $0.metric == metric && $0.isMeasured }),
                let value = feature.value,
                let baseline = baselines[metric],
                baseline.isReady,
                let median = baseline.median,
                let mad = baseline.mad
            else { return nil }

            let spread = mad * 1.5 / 0.6745
            let domain = spread * 3
            let normalized = { (input: Double) in
                min(max((input - (median - domain)) / (domain * 2), 0), 1)
            }
            let withinNormal = abs(value - median) <= spread

            return RangeGauge(
                label: MetricLabel.korean(for: metric),
                normalRange: normalized(median - spread)...normalized(median + spread),
                marker: normalized(value),
                caption: withinNormal ? "평소 범위 안" : (value > median ? "평소보다 큼" : "평소보다 작음")
            )
        }
    }
}
