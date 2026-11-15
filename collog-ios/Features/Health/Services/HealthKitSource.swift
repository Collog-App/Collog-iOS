//
//  HealthKitSource.swift
//  collog-ios
//

import Foundation
import HealthKit

/// 건강 앱과 맞닿는 부분. 테스트는 가짜를 넣는다.
protocol HealthRecordSource {
    /// 이 기기에서 건강 앱을 쓸 수 있는가.
    var isAvailable: Bool { get }

    /// 이 기기에서 아직 권한 창을 거치지 않았는가(앱을 다시 깔았거나 다른 휴대폰에서 연결함).
    /// HealthKit 은 읽기 권한을 허용했는지는 알려 주지 않고, 물어본 적이 있는지만 알려 준다.
    func needsAuthorization() async -> Bool

    /// 읽기 권한 창. 오류 없이 끝나도 허용했다는 뜻은 아니다(허용하지 않은 종류는 기록이 없는 것처럼 보인다).
    func requestAuthorization() async throws

    /// 읽다가 실패하면 던진다(일부만 올리지 않게).
    func read(days: [Date]) async throws -> HealthRecords
}

/// HealthKit 에서 하루 요약에 필요한 기록만 읽어 `HealthRecords`로 옮긴다. 쓰기 권한은 받지 않는다.
final class HealthKitSource: HealthRecordSource {
    static let readTypes: Set<HKObjectType> = [
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.stepCount),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRate),
        HKQuantityType(.bloodPressureSystolic),
        HKQuantityType(.bloodPressureDiastolic),
        HKQuantityType(.bloodGlucose),
    ]

    static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    static let milligramsPerDeciliter = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func needsAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        return status == .shouldRequest
    }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func read(days: [Date]) async throws -> HealthRecords {
        guard let first = days.first.map(HealthDailyCalculator.dayOf),
              let last = days.last.map(HealthDailyCalculator.dayOf) else { return HealthRecords() }
        let end = HealthDailyCalculator.adding(days: 1, to: last)
        // 수면은 끝난 시각으로 날을 정하므로, 일찍 시작한 세션도 빠지지 않게 하루 더 앞에서부터 읽는다
        let sleepStart = HealthDailyCalculator.sleepWindow(first).start.addingTimeInterval(-86_400)
        let sleepEnd = HealthDailyCalculator.sleepWindow(last).end

        let sleep = try await samples(.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: range(sleepStart, sleepEnd)))
            .map { SleepSample(start: $0.startDate, end: $0.endDate, value: $0.value) }
        let resting = try await samples(.quantitySample(type: HKQuantityType(.restingHeartRate), predicate: range(first, end)))
            .map { TimedSample(time: $0.startDate, value: $0.quantity.doubleValue(for: Self.beatsPerMinute)) }
        let pressures = try await samples(.correlation(type: HKCorrelationType(.bloodPressure), predicate: range(first, end)))
            .compactMap(Self.bloodPressure)
        let glucoses = try await samples(.quantitySample(type: HKQuantityType(.bloodGlucose), predicate: range(first, end)))
            .map {
                BloodGlucoseReading(
                    time: $0.startDate,
                    milligramsPerDeciliter: $0.quantity.doubleValue(for: Self.milligramsPerDeciliter)
                )
            }

        var records = HealthRecords(
            sleepSamples: sleep,
            stepsByDay: try await steps(from: first, to: end),
            restingHeartRates: resting,
            bloodPressures: pressures,
            bloodGlucoses: glucoses
        )
        // 안정 시 심박이 없는 날만 그날 수면 구간의 심박을 읽는다(분 단위 기록 전체는 읽지 않는다)
        for window in HealthDailyCalculator.heartRateWindows(days: days, records: records) {
            records.heartRates += try await samples(
                .quantitySample(type: HKQuantityType(.heartRate), predicate: range(window.start, window.end))
            ).map { TimedSample(time: $0.startDate, value: $0.quantity.doubleValue(for: Self.beatsPerMinute)) }
        }
        return records
    }

    /// 걸음은 HealthKit 통계(여러 기기의 겹친 기록을 걸러 낸 누적 합계)로 서울 자정부터 24시간씩 나눠 받는다.
    private func steps(from start: Date, to end: Date) async throws -> [Date: Double] {
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: range(start, end)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(hour: 24)
        )
        var result: [Date: Double] = [:]
        for statistics in try await descriptor.result(for: store).statistics() {
            guard let sum = statistics.sumQuantity() else { continue }
            result[HealthDailyCalculator.dayOf(statistics.startDate)] = sum.doubleValue(for: .count())
        }
        return result
    }

    private func samples<Sample: HKSample>(_ predicate: HKSamplePredicate<Sample>) async throws -> [Sample] {
        try await HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: []).result(for: store)
    }

    private func range(_ start: Date, _ end: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    }

    /// 혈압은 수축기·이완기를 묶은 기록(correlation)으로 읽는다.
    private static func bloodPressure(_ correlation: HKCorrelation) -> BloodPressureReading? {
        let systolic = correlation.objects(for: HKQuantityType(.bloodPressureSystolic)).first as? HKQuantitySample
        let diastolic = correlation.objects(for: HKQuantityType(.bloodPressureDiastolic)).first as? HKQuantitySample
        guard let systolic, let diastolic else { return nil }
        return BloodPressureReading(
            time: correlation.startDate,
            systolic: systolic.quantity.doubleValue(for: .millimeterOfMercury()),
            diastolic: diastolic.quantity.doubleValue(for: .millimeterOfMercury())
        )
    }
}
