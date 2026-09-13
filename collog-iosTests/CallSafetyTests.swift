//
//  CallSafetyTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct CallSafetyTests {
    @Test
    func loggedOutAndDifferentAccountsRejectIncomingIdentity() {
        #expect(!CallSafety.acceptsPush(userId: nil, calleeId: "parent"))
        #expect(!CallSafety.acceptsPush(userId: "child", calleeId: "parent"))
        #expect(!CallSafety.acceptsPush(userId: "parent", calleeId: nil))
        #expect(CallSafety.acceptsPush(userId: "parent", calleeId: "parent"))
    }

    @Test
    func revokedRecordingFlagOverridesOriginalRawCaptureRequest() {
        #expect(!CallSafety.canRecord(enabled: false, rawRequired: true, accepted: true, phase: .active))
        #expect(!CallSafety.canRecord(enabled: true, rawRequired: false, accepted: true, phase: .active))
        #expect(CallSafety.canRecord(enabled: true, rawRequired: true, accepted: true, phase: .active))
    }

    @Test(arguments: [CallPhase.connecting, .ringing, .reconnecting, .ended])
    func incompleteMediaDoesNotStartRecording(phase: CallPhase) {
        #expect(!CallSafety.canRecord(enabled: true, rawRequired: true, accepted: true, phase: phase))
        #expect(!CallSafety.canRecord(enabled: true, rawRequired: true, accepted: false, phase: .active))
    }

    @Test(arguments: [403, 404, 410])
    func permanentStatusFailureDoesNotPollForever(status: Int) {
        let error = APIError.server(status: status, code: "FAILED", message: "fixture")
        #expect(CallSafety.isPermanentStatusError(error))
        #expect(!CallSafety.canRetry(error))
    }

    @Test
    func onlyTemporaryAcceptErrorsRetry() {
        #expect(CallSafety.canRetry(APIError.transport("offline")))
        #expect(CallSafety.canRetry(APIError.server(status: 503, code: "FAILED", message: "fixture")))
        #expect(!CallSafety.canRetry(APIError.server(status: 409, code: "BUSY", message: "fixture")))
        #expect(!CallSafety.canRetry(APIError.unauthenticated))
        #expect(!CallSafety.canRetry(CancellationError()))
    }
}
