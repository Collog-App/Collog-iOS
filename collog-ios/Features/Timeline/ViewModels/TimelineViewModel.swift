//
//  TimelineViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class TimelineViewModel {
    var selectedTabIndex: Int
    private(set) var week: TimelineWeek = .sample
    private(set) var report: WeeklyReport = .sample
    private(set) var selectedMember: String = "어머니"

    let tabTitles = ["리포트", "타임라인"]

    init(selectedTabIndex: Int = 1) {
        self.selectedTabIndex = selectedTabIndex
    }
}
