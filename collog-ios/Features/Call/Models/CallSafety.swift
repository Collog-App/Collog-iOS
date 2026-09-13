//
//  CallSafety.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation

enum CallSafety {
    static func acceptsPush(userId: String?, calleeId: String?) -> Bool {
        guard let userId, let calleeId else { return false }
        return userId == calleeId
    }

    static func canRecord(enabled: Bool, rawRequired: Bool, accepted: Bool, phase: CallPhase) -> Bool {
        enabled && rawRequired && accepted && phase == .active
    }

    static func isPermanentStatusError(_ error: Error) -> Bool {
        if case APIError.unauthenticated = error { return true }
        if case let APIError.server(status, _, _) = error {
            return [403, 404, 410].contains(status)
        }
        return false
    }

    static func canRetry(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if case APIError.transport = error { return true }
        if case let APIError.server(status, _, _) = error { return status == 429 || status >= 500 }
        return error is URLError
    }
}
