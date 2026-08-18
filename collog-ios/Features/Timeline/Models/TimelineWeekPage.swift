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

    var title: String {
        let start = Self.bounds(offset: offset).start
        let month = Self.calendar.component(.month, from: start)
        let week = Self.calendar.component(.weekOfMonth, from: start)
        return "\(month)월 \(week)주"
    }

    var rangeText: String {
        let bounds = Self.bounds(offset: offset)
        return APIFormat.shortRange(
            from: APIFormat.isoDate.string(from: bounds.start),
            to: APIFormat.isoDate.string(from: bounds.end)
        )
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
