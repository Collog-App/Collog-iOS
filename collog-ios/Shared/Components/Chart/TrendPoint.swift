//
//  TrendPoint.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct TrendPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let label: String
    let value: Double

    static func == (lhs: TrendPoint, rhs: TrendPoint) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TrendSeries {
    let metricName: String
    let unit: String
    let points: [TrendPoint]
    let normalRange: ClosedRange<Double>

    var latest: TrendPoint? { points.last }

    var median: Double {
        (normalRange.lowerBound + normalRange.upperBound) / 2
    }

    func nearest(to date: Date) -> TrendPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    func isWithinNormalRange(_ point: TrendPoint) -> Bool {
        normalRange.contains(point.value)
    }
}

extension TrendSeries {
    static let speechRateSample: TrendSeries = {
        let values: [(String, Double)] = [
            ("7월 3주", 198), ("7월 4주", 205), ("8월 1주", 212),
            ("8월 2주", 209), ("8월 3주", 216), ("8월 4주", 210)
        ]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let points = values.enumerated().map { index, item in
            TrendPoint(
                date: calendar.date(byAdding: .weekOfYear, value: index - (values.count - 1), to: today) ?? today,
                label: item.0,
                value: item.1
            )
        }
        return TrendSeries(metricName: "말씀 속도", unit: "음절/분", points: points, normalRange: 195...220)
    }()

    static let speechRateFatherSample: TrendSeries = {
        let values: [(String, Double)] = [
            ("7월 3주", 184), ("7월 4주", 188), ("8월 1주", 187),
            ("8월 2주", 192), ("8월 3주", 190), ("8월 4주", 194)
        ]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let points = values.enumerated().map { index, item in
            TrendPoint(
                date: calendar.date(byAdding: .weekOfYear, value: index - (values.count - 1), to: today) ?? today,
                label: item.0,
                value: item.1
            )
        }
        return TrendSeries(metricName: "말씀 속도", unit: "음절/분", points: points, normalRange: 180...205)
    }()
}
