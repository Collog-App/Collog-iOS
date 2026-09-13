//
//  DateTimestampTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import Foundation
import Testing
@testable import collog_ios

struct DateTimestampTests {
    @Test(arguments: [
        "1970-01-01T00:00:00Z",
        "1970-01-01T00:00:00",
        "1970-01-01T09:00:00+09:00",
        "1969-12-31T19:00:00-05:00"
    ])
    func wholeSecondsPreserveTimeZone(timestamp: String) throws {
        let parsed = try #require(Date.fromCollogTimestamp(timestamp))
        #expect(parsed.timeIntervalSince1970 == 0)
    }

    @Test(arguments: [
        "1970-01-01T00:00:00.125Z",
        "1970-01-01T00:00:00.125",
        "1970-01-01T09:00:00.125+09:00",
        "1969-12-31T19:00:00.125-05:00"
    ])
    func fractionalSecondsPreserveTimeZone(timestamp: String) throws {
        let parsed = try #require(Date.fromCollogTimestamp(timestamp))
        #expect(abs(parsed.timeIntervalSince1970 - 0.125) < 0.001)
    }

    @Test(arguments: ["", "invalid", "2026-09-14", "2026-09-14Tinvalid"])
    func invalidTimestampReturnsNil(timestamp: String) {
        #expect(Date.fromCollogTimestamp(timestamp) == nil)
    }

    @Test
    func parsesOutsideMainActor() async throws {
        let parsed = await Task.detached {
            Date.fromCollogTimestamp("1970-01-01T09:00:00.125+09:00")
        }.value
        let date = try #require(parsed)
        #expect(abs(date.timeIntervalSince1970 - 0.125) < 0.001)
    }
}
