//
//  APIMapping.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum APIFormat {
    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()

    static func duration(seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60)분 \(seconds % 60)초" : "\(seconds)초"
    }

    static func weekTitle(from raw: String) -> String {
        guard let date = isoDate.date(from: raw) else { return raw }
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: date)
        let week = calendar.component(.weekOfMonth, from: date)
        return "\(month)월 \(week)주"
    }

    static func shortRange(from: String, to: String) -> String {
        guard let start = isoDate.date(from: from), let end = isoDate.date(from: to) else {
            return "\(from) ~ \(to)"
        }
        return "\(shortDate.string(from: start)) ~ \(shortDate.string(from: end))"
    }
}

extension TrendSeries {
    private static let normalRangeFactor = 1.5 / 0.6745

    init?(trend: AcousticTrendDTO, baseline: BaselineDTO?) {
        let points = trend.points.compactMap { point -> TrendPoint? in
            guard let value = point.value, let date = APIFormat.isoDate.date(from: point.date) else {
                return nil
            }
            return TrendPoint(date: date, label: APIFormat.shortDate.string(from: date), value: value)
        }
        guard points.count >= 2 else { return nil }

        let values = points.map(\.value)
        let range: ClosedRange<Double>
        if let baseline, baseline.isReady, let median = baseline.median, let mad = baseline.mad {
            let spread = mad * Self.normalRangeFactor
            range = (median - spread)...(median + spread)
        } else {
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 1
            let padding = max((maximum - minimum) * 0.2, 0.5)
            range = (minimum + padding)...(max(maximum - padding, minimum + padding + 0.1))
        }

        self.init(
            metricName: MetricLabel.korean(for: trend.metric),
            unit: MetricLabel.unit(for: trend.metric),
            points: points,
            normalRange: range,
            hasPersonalBaseline: baseline?.isReady == true
        )
    }
}

extension SafetyNotice {
    /// 통화 날짜는 기기 시간대와 상관없이 Asia/Seoul 로 센다(안드로이드와 같음).
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    /// 서버 고정 문구 그대로. 빈 문구는 없는 것으로 본다.
    static func text(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return raw
    }

    static func dayText(for date: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0)월 \(parts.day ?? 0)일 통화"
    }

    /// 최근 통화가 위로(서버와 같은 순서). 시각을 못 읽은 안내는 맨 아래에 받은 순서대로 둔다.
    static func list(from dtos: [SafetyNoticeDTO]) -> [SafetyNotice] {
        dtos
            .compactMap { dto -> (dto: SafetyNoticeDTO, text: String, date: Date?)? in
                guard let text = text(dto.text) else { return nil }
                return (dto, text, dto.observedAt.flatMap(Date.fromCollogTimestamp))
            }
            .enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.date, rhs.element.date) {
                case let (left?, right?) where left != right: left > right
                case (_?, nil): true
                case (nil, _?): false
                default: lhs.offset < rhs.offset
                }
            }
            .map { SafetyNotice(callId: $0.element.dto.callId, dayText: $0.element.date.map(dayText), text: $0.element.text) }
    }
}

extension WeeklyReport {
    init(dto: ReportDTO, trend: TrendSeries?) {
        let notices = SafetyNotice.list(from: dto.safetyNotices ?? [])
        guard dto.analyzedCallCount > 0 else {
            self = .empty
            safetyNotices = notices
            return
        }
        let labels = ["symptom": "증상", "medication": "복약", "activity": "활동", "sleep": "수면"]
        let symbols = [
            "symptom": "stethoscope",
            "medication": "pills",
            "activity": "figure.walk",
            "sleep": "moon"
        ]
        let groups = ["symptom", "medication", "activity", "sleep"].compactMap { key -> ConversationGroup? in
            guard let items = dto.conversationItems[key], !items.isEmpty else { return nil }
            return ConversationGroup(
                category: labels[key] ?? key,
                symbol: symbols[key] ?? "text.bubble",
                items: items
            )
        }

        let signals = (dto.promotedSignals.map { ($0, true) } + dto.acuteSignals.map { ($0, false) })
            .map { signal, promoted in
                ChangeSignalItem(
                    metricName: MetricLabel.korean(for: signal.metric),
                    summary: Self.summary(for: signal),
                    tone: promoted || signal.acute ? .watch : .steady,
                    isPromoted: promoted
                )
            }

        let itemCount = dto.conversationItems.values.reduce(0) { $0 + $1.count }

        self.init(
            state: Self.state(from: dto.state),
            noticeText: dto.emptyMessage,
            summaryStats: [
                CallStat(label: "분석된 통화", value: "\(dto.analyzedCallCount)", unit: "건", note: nil),
                CallStat(label: "기록된 대화", value: "\(itemCount)", unit: "개", note: nil)
            ],
            changeSignals: signals,
            conversationGroups: groups,
            repeatObservation: RepeatObservation(
                countText: "\(dto.repeatObservation.count)",
                perMinuteText: "통화 \(dto.repeatObservation.callsWithRepeat)건에서 관찰",
                caption: "대화 중 다시 물어보신 횟수예요"
            ),
            acousticTrend: trend,
            metricTrends: Self.metricTrends(from: dto),
            disclaimer: dto.disclaimer,
            safetyNotices: notices
        )
    }

    private static func metricTrends(from dto: ReportDTO) -> [MetricTrend] {
        let history = dto.recentAcousticHistory ?? dto.acousticTrends
        return history.compactMap { item in
            let values = item.points.compactMap(\.value)
            guard values.count >= 2, let latest = values.last else { return nil }

            return MetricTrend(
                label: MetricLabel.korean(for: item.metric),
                value: String(Int(latest.rounded())),
                unit: MetricLabel.unit(for: item.metric),
                values: values,
                shape: item.metric == "COUGH_EVENTS" ? .bar : .line
            )
        }
    }

    private static func state(from raw: String) -> ReportState {
        switch raw {
        case "EMPTY": .empty
        case "BASELINE_COLLECTING": .baselineCollecting
        default: .ready
        }
    }

    private static func summary(for signal: SignalDTO) -> String {
        if let text = signal.summaryText { return text }
        if let text = signal.acuteText { return text }
        if let comparison = signal.vsRolling ?? signal.vsAnchor {
            return String(format: "평소 대비 %+.0f%%", comparison.deltaPct)
        }
        return "변화를 관찰하고 있어요"
    }
}
