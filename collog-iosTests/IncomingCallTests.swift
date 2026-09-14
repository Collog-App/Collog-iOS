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

    @Test
    func recordingIndicatorKeepsItsLayoutSpaceWhenHidden() {
        let visible = UIHostingController(rootView: CallRecordingIndicator(isRecording: true))
        let hidden = UIHostingController(rootView: CallRecordingIndicator(isRecording: false))
        let available = CGSize(width: 320, height: 200)
        let visibleSize = visible.sizeThatFits(in: available)
        let hiddenSize = hidden.sizeThatFits(in: available)
        #expect(visibleSize.height > 0)
        #expect(hiddenSize == visibleSize)
    }

    private func incomingCall(phase: CallPhase = .ringing) -> CallCenter.ActiveCall {
        CallCenter.ActiveCall(
            id: "incoming", uuid: UUID(), direction: .incoming,
            peerId: "peer", peerName: "가족", phase: phase, questions: []
        )
    }
}
