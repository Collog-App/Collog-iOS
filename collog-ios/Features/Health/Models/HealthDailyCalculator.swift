//
//  HealthDailyCalculator.swift
//  collog-ios
//

import Foundation
import HealthKit

/// 수면 기록 한 구간. `value`는 HealthKit `HKCategoryValueSleepAnalysis` 원시값이다.
struct SleepSample: Equatable {
    let start: Date
    let end: Date
    let value: Int
}

/// 한 시각의 값(심박 bpm 등).
struct TimedSample: Equatable {
    let time: Date
    let value: Double
}

struct BloodPressureReading: Equatable {
    let time: Date
    let systolic: Double
    let diastolic: Double
}

/// 혈당은 HealthKit 에서 mg/dL 로 바꿔 읽는다.
struct BloodGlucoseReading: Equatable {
    let time: Date
    let milligramsPerDeciliter: Double
}

/// 건강 앱에서 읽어 옮긴 값. 걸음은 HealthKit 이 서울 하루씩 합친 누적 합계이고, 키는 그날 서울 자정이다.
struct HealthRecords {
    var sleepSamples: [SleepSample] = []
    var stepsByDay: [Date: Double] = [:]
    var restingHeartRates: [TimedSample] = []
    var heartRates: [TimedSample] = []
    var bloodPressures: [BloodPressureReading] = []
    var bloodGlucoses: [BloodGlucoseReading] = []
}

/// 건강 앱 연결 약속(2026-11-08) 「동기화」 규칙으로 하루 요약을 만든다. 날짜는 모두 Asia/Seoul 이고,
/// 하루는 그날 서울 자정(`Date`)으로 나타낸다. 서버 범위 검사를 벗어난 값은 그 칸만 nil 로 둔다
/// (한 칸 때문에 요청 전체가 422 로 거절되지 않게). 혈압·혈당은 범위 안 측정값 중 그날 마지막 것을 고른다.
enum HealthDailyCalculator {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    /// 동기화 때마다 다시 계산해 올리는 날 수(오늘 포함).
    static let syncDayCount = 14

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 잔 단계: 수면(구분 없음)·코어·깊은 수면·렘.
    private static let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
    private static let awakeValue = HKCategoryValueSleepAnalysis.awake.rawValue
    private static let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue

    static func dayOf(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func dayString(_ day: Date) -> String { dayFormatter.string(from: day) }

    /// "yyyy-MM-dd" → 그날 서울 자정.
    static func day(from string: String) -> Date? { dayFormatter.date(from: string) }

    static func adding(days: Int, to day: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: day) ?? day.addingTimeInterval(Double(days) * 86_400)
    }

    /// 오늘까지 14일(오래된 날부터).
    static func syncDays(today: Date) -> [Date] {
        let today = dayOf(today)
        return (0..<syncDayCount).reversed().map { adding(days: -$0, to: today) }
    }

    /// `day`의 수면으로 셀 세션이 끝나는 구간: D-1 18:00 이상, D 18:00 미만. 한국은 일광 절약 시간이 없다.
    static func sleepWindow(_ day: Date) -> DateInterval {
        let day = dayOf(day)
        return DateInterval(start: day.addingTimeInterval(-6 * 3600), end: day.addingTimeInterval(18 * 3600))
    }

    /// HealthKit 은 세션 없이 단계 구간(침대·수면·깸)만 적는다. 겹치거나 맞닿은 구간을 묶어 밤 하나(세션)로 만든다.
    static func sessions(_ samples: [SleepSample]) -> [DateInterval] {
        union(samples.compactMap(interval))
    }

    /// `day`의 수면 세션: 끝난 시각이 수면 구간 안인 세션.
    static func sessions(for day: Date, in sessions: [DateInterval]) -> [DateInterval] {
        let window = sleepWindow(day)
        return sessions.filter { $0.end >= window.start && $0.end < window.end }
    }

    /// 안정 시 심박이 없는 날의 수면 세션 구간. 그 구간의 심박 샘플만 읽으면 된다.
    static func heartRateWindows(days: [Date], records: HealthRecords) -> [DateInterval] {
        let all = sessions(records.sleepSamples)
        let restingDays = Set(records.restingHeartRates.map { dayOf($0.time) })
        var windows: [DateInterval] = []
        for day in days.map(dayOf) where !restingDays.contains(day) {
            for session in sessions(for: day, in: all) where !windows.contains(session) {
                windows.append(session)
            }
        }
        return windows
    }

    static func summaries(days: [Date], records: HealthRecords) -> [HealthDayDTO] {
        let all = sessions(records.sleepSamples)
        return days.map { summary(day: $0, sessions: all, records: records) }
    }

    static func summary(day: Date, records: HealthRecords) -> HealthDayDTO {
        summary(day: day, sessions: sessions(records.sleepSamples), records: records)
    }

    /// 그날 세션 안의 잔 단계 구간(없으면 침대에 있던 구간)을 합집합으로 모은 뒤 깬 구간을 뺀다.
    /// 여러 기기·앱이 같은 밤을 겹쳐 적어도 두 번 세지 않는다. 세션이 없거나 잔 구간이 없으면 nil.
    static func sleepMinutes(sessions: [DateInterval], samples: [SleepSample]) -> Int? {
        let inside = samples.filter { sample in
            sessions.contains { $0.start <= sample.start && sample.end <= $0.end }
        }
        let asleep = inside.filter { asleepValues.contains($0.value) }
        let slept = asleep.isEmpty ? inside.filter { $0.value == inBedValue } : asleep
        let base = union(slept.compactMap(interval))
        guard !base.isEmpty else { return nil }
        let awake = union(inside.filter { $0.value == awakeValue }.compactMap(interval))
        let seconds = minus(base, awake).reduce(0) { $0 + $1.duration }
        return rounded((seconds / 60).rounded(.down), in: 0...1440)
    }

    /// 그날 안정 시 심박 기록의 평균, 없으면 그날 수면 세션 구간의 심박 샘플 평균. 반올림.
    static func restingHeartRate(day: Date, sessions: [DateInterval], records: HealthRecords) -> Int? {
        let resting = records.restingHeartRates.filter { dayOf($0.time) == day }
        let values = resting.isEmpty
            ? records.heartRates.filter { sample in sessions.contains { $0.contains(sample.time) } }
            : resting
        guard !values.isEmpty else { return nil }
        return rounded(values.map(\.value).reduce(0, +) / Double(values.count), in: 25...220)
    }

    /// 수축기 50~260, 이완기 30~200, 이완기 < 수축기. 벗어나면 둘 다 nil.
    static func bloodPressure(systolic: Double, diastolic: Double) -> (systolic: Int, diastolic: Int)? {
        guard let high = rounded(systolic, in: 50...260),
              let low = rounded(diastolic, in: 30...200),
              low < high else { return nil }
        return (high, low)
    }

    /// 소수 첫째 자리까지 반올림한 mg/dL. 20~600 을 벗어나면 nil.
    static func bloodGlucose(_ milligramsPerDeciliter: Double) -> Double? {
        let value = (milligramsPerDeciliter * 10).rounded() / 10
        return (20.0...600.0).contains(value) ? value : nil
    }

    private static func summary(day: Date, sessions all: [DateInterval], records: HealthRecords) -> HealthDayDTO {
        let day = dayOf(day)
        let sessions = sessions(for: day, in: all)
        let pressure = records.bloodPressures
            .filter { dayOf($0.time) == day }
            .sorted { $0.time > $1.time }
            .lazy
            .compactMap { bloodPressure(systolic: $0.systolic, diastolic: $0.diastolic) }
            .first
        let glucose = records.bloodGlucoses
            .filter { dayOf($0.time) == day }
            .sorted { $0.time > $1.time }
            .lazy
            .compactMap { bloodGlucose($0.milligramsPerDeciliter) }
            .first
        return HealthDayDTO(
            date: dayString(day),
            sleepMinutes: sleepMinutes(sessions: sessions, samples: records.sleepSamples),
            steps: records.stepsByDay[day].flatMap { rounded($0, in: 0...100_000) },
            restingHeartRate: restingHeartRate(day: day, sessions: sessions, records: records),
            bloodPressureSystolic: pressure?.systolic,
            bloodPressureDiastolic: pressure?.diastolic,
            bloodGlucoseMgDl: glucose
        )
    }

    /// 반올림한 값이 `range` 안이면 그 값, 아니면 nil(NaN·무한대도 nil).
    private static func rounded(_ value: Double, in range: ClosedRange<Int>) -> Int? {
        let value = value.rounded()
        guard value >= Double(range.lowerBound), value <= Double(range.upperBound) else { return nil }
        return Int(value)
    }

    private static func interval(_ sample: SleepSample) -> DateInterval? {
        sample.start < sample.end ? DateInterval(start: sample.start, end: sample.end) : nil
    }

    /// 겹치거나 맞닿은 구간을 하나로 합친다(시작 순).
    private static func union(_ spans: [DateInterval]) -> [DateInterval] {
        var merged: [DateInterval] = []
        for span in spans.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, span.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, span.end))
            } else {
                merged.append(span)
            }
        }
        return merged
    }

    /// 합쳐진 `spans`에서 합쳐진 `holes`를 뺀 구간들.
    private static func minus(_ spans: [DateInterval], _ holes: [DateInterval]) -> [DateInterval] {
        spans.flatMap { span -> [DateInterval] in
            var pieces: [DateInterval] = []
            var cursor = span.start
            for hole in holes {
                if hole.start >= span.end { break }
                if cursor < hole.start { pieces.append(DateInterval(start: cursor, end: hole.start)) }
                if cursor < hole.end { cursor = hole.end }
            }
            if cursor < span.end { pieces.append(DateInterval(start: cursor, end: span.end)) }
            return pieces
        }
    }
}
