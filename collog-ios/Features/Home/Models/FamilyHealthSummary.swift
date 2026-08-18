//
//  FamilyHealthSummary.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct MetricHighlight {
    let prefix: String
    let value: String
    let suffix: String
}

struct FamilyHealthSummary {
    let memberName: String
    let statusPrefix: String
    let statusHeadline: String
    let highlight: MetricHighlight
    let location: String
    let chartStartLabel: String
    let chartEndLabel: String
}

struct HealthFeedback {
    let title: String
    let headline: String
    let tags: [String]
}

extension FamilyHealthSummary {
    static let sample = FamilyHealthSummary(
        memberName: "어머니",
        statusPrefix: "정상이지만",
        statusHeadline: "정기적인 점검이 필요해요",
        highlight: MetricHighlight(prefix: "저번주보다 휴지 비율이", value: "4% 더", suffix: "높아요"),
        location: "경기도 과천시",
        chartStartLabel: "일요일",
        chartEndLabel: "토요일"
    )
}

extension HealthFeedback {
    static let sample = HealthFeedback(
        title: "건강 피드백",
        headline: "인지 장애 우려",
        tags: ["최근 기록", "3일 전 통화"]
    )
}
