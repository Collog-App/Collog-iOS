//
//  LifeRecord.swift
//  collog-ios
//

import Foundation

/// 막대 하나: 그날 값이 없으면 `value`가 nil.
struct LifeRecordDay: Equatable, Identifiable {
    let date: Date
    let label: String
    let value: Double?

    var id: Date { date }
}

/// 최근 값과 그 날짜(「64 회/분 · 11월 7일」).
struct LifeRecordLatest: Equatable {
    let value: String
    let unit: String
    let dateText: String
}

/// 리포트 「생활 기록」 카드에 보이는 값. 진단 표현 없이 기록된 값만 보여 준다. 날짜는 서울 자정.
struct LifeRecord: Equatable {
    static let defaultDisclaimer = "이 정보는 의료 진단이 아니며 건강 변화 참고용입니다."

    let connected: Bool
    let rangeText: String
    let sleep: [LifeRecordDay]
    let sleepAverageText: String?
    let steps: [LifeRecordDay]
    let stepsAverageText: String?
    let restingHeartRate: LifeRecordLatest?
    let bloodPressure: LifeRecordLatest?
    let bloodGlucose: LifeRecordLatest?
    let lastSyncedText: String?
    let disclaimer: String

    private static let weekday: DateFormatter = formatter("E")
    private static let shortDate: DateFormatter = formatter("M/d")

    /// `end`까지 7일을 막대로, 그 앞 기록까지 포함해 가장 최근 심박·혈압·혈당을 보여 준다.
    init(dto: ParentHealthDailyDTO, end: Date, today: Date) {
        let end = HealthDailyCalculator.dayOf(end)
        var byDate: [Date: HealthDayDTO] = [:]
        for day in dto.days {
            guard let date = HealthDailyCalculator.day(from: day.date), date <= end else { continue }
            byDate[date] = day
        }
        let week = (0..<7).reversed().map { HealthDailyCalculator.adding(days: -$0, to: end) }
        let recent = byDate.sorted { $0.key > $1.key }

        connected = dto.connected
        rangeText = end == HealthDailyCalculator.dayOf(today)
            ? "최근 7일"
            : "\(Self.shortDate.string(from: week[0])) ~ \(Self.shortDate.string(from: end))"
        sleep = week.map { LifeRecordDay(date: $0, label: Self.weekday.string(from: $0), value: byDate[$0]?.sleepMinutes.map(Double.init)) }
        steps = week.map { LifeRecordDay(date: $0, label: Self.weekday.string(from: $0), value: byDate[$0]?.steps.map(Double.init)) }
        sleepAverageText = Self.average(sleep).map { Self.sleepText(Int($0.rounded())) }
        stepsAverageText = Self.average(steps).map {
            "\(Int($0.rounded()).formatted(.number.locale(Locale(identifier: "ko_KR"))))걸음"
        }
        restingHeartRate = Self.latest(recent) { day in day.restingHeartRate.map { ("\($0)", "회/분") } }
        bloodPressure = Self.latest(recent) { day in
            guard let high = day.bloodPressureSystolic, let low = day.bloodPressureDiastolic else { return nil }
            return ("\(high)/\(low)", "mmHg")
        }
        bloodGlucose = Self.latest(recent) { day in day.bloodGlucoseMgDl.map { (Self.glucoseText($0), "mg/dL") } }
        lastSyncedText = dto.lastSyncedDay.flatMap(HealthDailyCalculator.day(from:)).map(Self.dayText)
        let disclaimer = dto.disclaimer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.disclaimer = disclaimer.isEmpty ? Self.defaultDisclaimer : disclaimer
    }

    /// 체험 모드의 예시. 다른 체험 데이터처럼 고정 값이다.
    static func sample(end: Date, today: Date) -> LifeRecord {
        let sleepMinutes = [412, 385, 440, 366, 401, 428, 395]
        let steps = [5120, 3480, 6210, 4890, 2950, 5730, 4410]
        let days = (0..<7).map { index in
            HealthDayDTO(
                date: HealthDailyCalculator.dayString(HealthDailyCalculator.adding(days: index - 6, to: end)),
                sleepMinutes: sleepMinutes[index],
                steps: steps[index],
                restingHeartRate: index == 6 ? 64 : nil,
                bloodPressureSystolic: index == 5 ? 128 : nil,
                bloodPressureDiastolic: index == 5 ? 82 : nil,
                bloodGlucoseMgDl: index == 4 ? 112 : nil
            )
        }
        let dto = ParentHealthDailyDTO(
            parentId: "sample",
            connected: true,
            platform: CollogAPI.healthPlatform,
            lastSyncedDay: HealthDailyCalculator.dayString(end),
            days: days,
            disclaimer: nil
        )
        return LifeRecord(dto: dto, end: end, today: today)
    }

    /// 「6시간 10분」, 「45분」, 「7시간」.
    static func sleepText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)분" }
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }

    /// 「11월 7일」.
    static func dayText(_ date: Date) -> String {
        let components = HealthDailyCalculator.calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)월 \(components.day ?? 0)일"
    }

    private static func glucoseText(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private static func average(_ days: [LifeRecordDay]) -> Double? {
        let values = days.compactMap(\.value)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func latest(
        _ recent: [(key: Date, value: HealthDayDTO)],
        _ value: (HealthDayDTO) -> (String, String)?
    ) -> LifeRecordLatest? {
        for (date, day) in recent {
            if let (text, unit) = value(day) { return LifeRecordLatest(value: text, unit: unit, dateText: dayText(date)) }
        }
        return nil
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = HealthDailyCalculator.calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
