//
//  HealthCondition.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum HealthCondition: String, CaseIterable, Identifiable {
    case diabetes = "DIABETES"
    case hypertension = "HYPERTENSION"
    case dyslipidemia = "DYSLIPIDEMIA"
    case asthma = "ASTHMA"
    case obesity = "OBESITY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diabetes: "당뇨"
        case .hypertension: "고혈압"
        case .dyslipidemia: "이상지질혈증"
        case .asthma: "천식"
        case .obesity: "비만"
        }
    }
}

enum UserRoleOption: String, CaseIterable, Identifiable {
    case child = "CHILD"
    case parent = "PARENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .child: "자녀"
        case .parent: "부모"
        }
    }
}
