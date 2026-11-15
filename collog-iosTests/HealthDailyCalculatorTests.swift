//
//  HealthDailyCalculatorTests.swift
//  collog-ios
//

import Foundation
import HealthKit
import Testing
@testable import collog_ios

/// 건강 앱 연결 약속(2026-11-08) 「동기화」 규칙: 서울 하루, 수면 구간(D-1 18:00 ~ D 18:00, 끝난 시각 기준·깸 제외),
/// 걸음 누적 합계, 안정 시 심박(없으면 수면 중 심박), 혈압·혈당 그날 마지막 측정, 서버 범위 검사.
@MainActor
struct HealthDailyCalculatorTests {
    private let asleepCore = HKCategoryValueSleepAnalysis.asleepCore.rawValue
    private let asleepDeep = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
    private let asleepREM = HKCategoryValueSleepAnalysis.asleepREM.rawValue
    private let asleepUnspecified = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    private let awake = HKCategoryValueSleepAnalysis.awake.rawValue
    private let inBed = HKCategoryValueSleepAnalysis.inBed.rawValue

    @Test func syncDaysAreFourteenSeoulDaysEndingToday() {
        // 서울 11-08 00:30 = UTC 11-07 15:30. 기기 시간대와 상관없이 서울 날짜로 센다
        let days = HealthDailyCalculator.syncDays(today: seoul(11, 8, 0, 30))
        #expect(days.count == 14)
        #expect(days.map(HealthDailyCalculator.dayString).first == "2026-10-26")
        #expect(days.map(HealthDailyCalculator.dayString).last == "2026-11-08")
        #expect(HealthDailyCalculator.calendar.timeZone.identifier == "Asia/Seoul")
    }

    @Test func sleepWindowRunsFromPreviousSixPMToSixPM() {
        let window = HealthDailyCalculator.sleepWindow(seoul(11, 8))
        #expect(window.start == seoul(11, 7, 18))
        #expect(window.end == seoul(11, 8, 18))
    }

    @Test func sleepCountsAsleepStagesOnceAndSkipsAwakeAndInBed() {
        let samples = [
            // 아이폰이 적은 침대 구간은 잔 단계가 있으면 세지 않는다
            SleepSample(start: seoul(11, 7, 22, 30), end: seoul(11, 8, 7), value: inBed),
            SleepSample(start: seoul(11, 7, 23), end: seoul(11, 8, 1), value: asleepCore),
            SleepSample(start: seoul(11, 8, 1), end: seoul(11, 8, 1, 20), value: awake),
            SleepSample(start: seoul(11, 8, 1, 20), end: seoul(11, 8, 3), value: asleepDeep),
            SleepSample(start: seoul(11, 8, 3), end: seoul(11, 8, 6, 30), value: asleepREM),
            // 다른 앱이 같은 밤을 겹쳐 적어도 두 번 세지 않는다
            SleepSample(start: seoul(11, 7, 23, 30), end: seoul(11, 8, 2), value: asleepUnspecified),
        ]
        let day = HealthDailyCalculator.summary(day: seoul(11, 8), records: HealthRecords(sleepSamples: samples))
        // 23:00~06:30 (450분) - 깸 20분
        #expect(day.sleepMinutes == 430)
        #expect(HealthDailyCalculator.summary(day: seoul(11, 7), records: HealthRecords(sleepSamples: samples)).sleepMinutes == nil)
    }

    @Test func sleepFallsBackToInBedWithoutStages() {
        let samples = [
            SleepSample(start: seoul(11, 7, 23), end: seoul(11, 8, 7), value: inBed),
            SleepSample(start: seoul(11, 8, 3), end: seoul(11, 8, 3, 30), value: awake),
        ]
        #expect(HealthDailyCalculator.summary(day: seoul(11, 8), records: HealthRecords(sleepSamples: samples)).sleepMinutes == 450)

        let onlyAwake = [SleepSample(start: seoul(11, 8, 3), end: seoul(11, 8, 3, 30), value: awake)]
        #expect(HealthDailyCalculator.summary(day: seoul(11, 8), records: HealthRecords(sleepSamples: onlyAwake)).sleepMinutes == nil)
    }

    @Test func sleepDayIsDecidedBySessionEndTime() {
        let samples = [
            // 정확히 18:00 에 끝나면 다음 날 수면
            SleepSample(start: seoul(11, 7, 16), end: seoul(11, 7, 18), value: asleepUnspecified),
            SleepSample(start: seoul(11, 8, 15), end: seoul(11, 8, 15, 30), value: asleepUnspecified),
            // 18:00 을 넘겨 끝나면 그다음 날
            SleepSample(start: seoul(11, 8, 17), end: seoul(11, 8, 18, 30), value: asleepUnspecified),
        ]
        let records = HealthRecords(sleepSamples: samples)
        let days = HealthDailyCalculator.summaries(days: [seoul(11, 7), seoul(11, 8), seoul(11, 9)], records: records)
        #expect(days.map(\.sleepMinutes) == [nil, 150, 90])
    }

    @Test func sleepLongerThanADayIsDropped() {
        let samples = [SleepSample(start: seoul(11, 7, 2), end: seoul(11, 8, 3), value: inBed)]
        #expect(HealthDailyCalculator.summary(day: seoul(11, 8), records: HealthRecords(sleepSamples: samples)).sleepMinutes == nil)
    }

    @Test func stepsOutsideServerRangeAreDropped() {
        let records = HealthRecords(stepsByDay: [
            seoul(11, 6): 100_000.4,
            seoul(11, 7): 100_001,
            seoul(11, 8): 3_210,
        ])
        let days = HealthDailyCalculator.summaries(days: [seoul(11, 6), seoul(11, 7), seoul(11, 8)], records: records)
        #expect(days.map(\.steps) == [100_000, nil, 3_210])
    }

    @Test func restingHeartRateAveragesThenFallsBackToSleepHeartRate() {
        let records = HealthRecords(
            sleepSamples: [SleepSample(start: seoul(11, 7, 23), end: seoul(11, 8, 6), value: asleepCore)],
            restingHeartRates: [
                TimedSample(time: seoul(11, 7, 9), value: 62),
                TimedSample(time: seoul(11, 7, 21), value: 65),
                TimedSample(time: seoul(11, 9, 9), value: 230),
            ],
            heartRates: [
                TimedSample(time: seoul(11, 8, 1), value: 58),
                TimedSample(time: seoul(11, 8, 2), value: 60),
                TimedSample(time: seoul(11, 8, 6), value: 61),
                // 수면 구간 밖 심박은 세지 않는다
                TimedSample(time: seoul(11, 8, 12), value: 120),
            ]
        )
        let days = HealthDailyCalculator.summaries(days: [seoul(11, 7), seoul(11, 8), seoul(11, 9)], records: records)
        // 63.5 → 64, 수면 중 59.67 → 60, 범위(25~220) 밖 → nil
        #expect(days.map(\.restingHeartRate) == [64, 60, nil])
        #expect(
            HealthDailyCalculator.heartRateWindows(days: [seoul(11, 7), seoul(11, 8)], records: records)
                == [DateInterval(start: seoul(11, 7, 23), end: seoul(11, 8, 6))]
        )
    }

    @Test func bloodPressureIsLastValidReadingOfTheSeoulDay() {
        let records = HealthRecords(bloodPressures: [
            BloodPressureReading(time: seoul(11, 8, 8), systolic: 120.4, diastolic: 79.6),
            // 이완기가 수축기보다 크거나 같으면 버리고 그 앞 측정을 쓴다
            BloodPressureReading(time: seoul(11, 8, 20), systolic: 130, diastolic: 140),
            // 서울 11-09 00:10(UTC 11-08)은 11-09 측정이다
            BloodPressureReading(time: seoul(11, 9, 0, 10), systolic: 300, diastolic: 90),
        ])
        let days = HealthDailyCalculator.summaries(days: [seoul(11, 8), seoul(11, 9)], records: records)
        #expect(days[0].bloodPressureSystolic == 120)
        #expect(days[0].bloodPressureDiastolic == 80)
        #expect(days[1].bloodPressureSystolic == nil)
        #expect(days[1].bloodPressureDiastolic == nil)
        let edge = HealthDailyCalculator.bloodPressure(systolic: 260, diastolic: 30)
        #expect(edge?.systolic == 260 && edge?.diastolic == 30)
        #expect(HealthDailyCalculator.bloodPressure(systolic: 120, diastolic: 29) == nil)
        #expect(HealthDailyCalculator.bloodPressure(systolic: .nan, diastolic: 80) == nil)
    }

    @Test func bloodGlucoseIsLastValidReadingRoundedToOneDecimal() {
        let records = HealthRecords(bloodGlucoses: [
            BloodGlucoseReading(time: seoul(11, 8, 7), milligramsPerDeciliter: 98.04),
            BloodGlucoseReading(time: seoul(11, 8, 21), milligramsPerDeciliter: 650),
        ])
        #expect(HealthDailyCalculator.summary(day: seoul(11, 8), records: records).bloodGlucoseMgDl == 98.0)
        #expect(HealthDailyCalculator.bloodGlucose(600.04) == 600.0)
        #expect(HealthDailyCalculator.bloodGlucose(19.9) == nil)
    }

    @Test func healthKitUnitsConvertGlucoseToMgPerDlAndHeartRateToBpm() {
        let millimolesPerLiter = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose)
            .unitDivided(by: .liter())
        let glucose = HKQuantity(unit: millimolesPerLiter, doubleValue: 5.5)
            .doubleValue(for: HealthKitSource.milligramsPerDeciliter)
        #expect(HealthDailyCalculator.bloodGlucose(glucose) == 99.1)
        let perSecond = HKQuantity(unit: HKUnit.count().unitDivided(by: .second()), doubleValue: 1)
        #expect(perSecond.doubleValue(for: HealthKitSource.beatsPerMinute) == 60)
    }

    @Test func emptyDaysHaveNoValues() {
        let days = HealthDailyCalculator.summaries(days: [seoul(11, 8)], records: HealthRecords())
        #expect(days == [HealthDayDTO(date: "2026-11-08")])
        #expect(!days[0].hasAnyValue)
    }

    private func seoul(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        HealthDailyCalculator.calendar.date(
            from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}
