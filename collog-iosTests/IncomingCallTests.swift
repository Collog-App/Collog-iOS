//
//  IncomingCallTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import Foundation
import SwiftUI
import Testing
@testable import collog_ios

@MainActor
struct IncomingCallTests {
    @Test
    func answerWaitsForSystemRegistrationAndRejectsDuplicateRequests() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let center = CallCenter(environment: fixture.environment)
        center.activeCall = incomingCall()
        #expect(!center.canAnswerIncomingCall)
        center.incomingCallReported = true
        #expect(center.canAnswerIncomingCall)
        center.incomingAnswerRequested = true
        #expect(!center.canAnswerIncomingCall)
        center.incomingAnswerRequested = false
        center.activeCall = nil
        #expect(!center.canAnswerIncomingCall)
    }

    @Test(arguments: [CallPhase.connecting, .active, .reconnecting, .ended])
    func onlyRingingCallsOfferAnswer(phase: CallPhase) throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let center = CallCenter(environment: fixture.environment)
        center.incomingCallReported = true
        center.activeCall = incomingCall(phase: phase)
        #expect(!center.canAnswerIncomingCall)
    }

    @Test
    func outgoingCallNeverOffersAnswer() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let center = CallCenter(environment: fixture.environment)
        center.incomingCallReported = true
        center.activeCall = CallCenter.ActiveCall(
            id: "outgoing", uuid: UUID(), direction: .outgoing,
            peerId: "peer", peerName: "가족", phase: .ringing, questions: []
        )
        #expect(!center.canAnswerIncomingCall)
    }

    private func incomingCall(phase: CallPhase = .ringing) -> CallCenter.ActiveCall {
        CallCenter.ActiveCall(
            id: "incoming", uuid: UUID(), direction: .incoming,
            peerId: "peer", peerName: "가족", phase: phase, questions: []
        )
    }
}
