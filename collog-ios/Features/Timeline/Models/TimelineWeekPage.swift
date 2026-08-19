//
//  TimelineWeekPage.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import Foundation

struct TimelineWeekPage: Identifiable {
    let offset: Int
    var entries: [CallTimelineEntry] = []
    var report: WeeklyReport = .empty
    var isLoaded = false

    var id: Int { offset }

    private var startDate: Date { Self.bounds(offset: offset).start }

    var month: Int { Self.calendar.component(.month, from: startDate) }

    var weekTitle: String {
        let week = Self.calendar.component(.weekOfMonth, from: startDate)
        return "\(week)주"
    }

    var title: String {
        "\(month)월 \(weekTitle)"
    }

    var rangeText: String {
        let bounds = Self.bounds(offset: offset)
        return APIFormat.shortRange(
            from: APIFormat.isoDate.string(from: bounds.start),
            to: APIFormat.isoDate.string(from: bounds.end)
        )
    }

    var timelineRangeText: String {
        let bounds = Self.bounds(offset: offset)
        let startDay = Self.calendar.component(.day, from: bounds.start)
        let endDay = Self.calendar.component(.day, from: bounds.end)
        return "\(startDay)일부터 \(endDay)일"
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }()

    static func bounds(offset: Int) -> (anchor: Date, start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())
        let anchor = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? anchor

        return (anchor, start, end)
    }
}
