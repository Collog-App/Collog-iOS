//
//  CallPhase.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum CallPhase: Equatable {
    case connecting
    case ringing
    case active
    case ended

    var statusText: String {
        switch self {
        case .connecting: "통화 연결 중..."
        case .ringing: "받을 때까지 기다리는 중"
        case .active: ""
        case .ended: "통화 종료"
        }
    }

    var showsTimer: Bool { self == .active }
}

enum CallDurationFormatter {
    static func text(for interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
