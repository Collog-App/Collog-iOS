//
//  MainTab.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case report
    case timeline
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "홈"
        case .report: "리포트"
        case .timeline: "타임라인"
        case .settings: "설정"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .report: "doc.text.fill"
        case .timeline: "chart.xyaxis.line"
        case .settings: "gearshape.fill"
        }
    }
}
