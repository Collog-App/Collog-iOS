//
//  AnalysisEmptyActionTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct AnalysisEmptyActionTests {
    @Test
    func missingCallableFamilyOffersInvitation() {
        #expect(resolve(canCall: false) == .family)
        #expect(resolve(canCall: true) == .call)
    }

    @Test
    func historicalWeekOffersCurrentWeekWithoutCalling() {
        #expect(resolve(canCall: true, isCurrentWeek: false) == .currentWeek)
    }

    @Test
    func guestDoesNotOfferRealCallOrInvitation() {
        #expect(resolve(canCall: false, isGuest: true) == .none)
    }

    @Test(arguments: ["ENDED", "PROCESSING"])
    func recordedPendingCallOffersStatus(state: String) {
        #expect(resolve(calls: [call(state: state, recorded: true)]) == .processing)
    }

    @Test(arguments: ["ANALYZED", "ANALYSIS_EXCLUDED", "ANALYSIS_FAILED", "ACTIVE"])
    func terminalAndActiveCallsDoNotClaimAnalysisIsPending(state: String) {
        #expect(resolve(calls: [call(state: state, recorded: true)]) == .call)
    }

    @Test
    func unrecordedEndedCallDoesNotOfferAnalysisStatus() {
        #expect(resolve(calls: [call(state: "ENDED", recorded: false)]) == .call)
    }

    @Test
    func statusUsesLatestFamilyCallList() {
        let states = AnalysisCallStatusSnapshot.states(
            for: [call(state: "PROCESSING", recorded: true)],
            refreshedCalls: [call(state: "ANALYZED", recorded: true)]
        )
        #expect(states["call"] == "ANALYZED")
    }

    @Test
    func removedCallDoesNotKeepOldProcessingState() {
        let states = AnalysisCallStatusSnapshot.states(
            for: [call(state: "PROCESSING", recorded: true)], refreshedCalls: []
        )
        #expect(states["call"] == "UNAVAILABLE")
    }

    private func resolve(
        calls: [CallSummaryDTO] = [], canCall: Bool = true,
        isCurrentWeek: Bool = true, isGuest: Bool = false
    ) -> AnalysisEmptyAction {
        .resolve(calls: calls, canCall: canCall, isCurrentWeek: isCurrentWeek, isGuest: isGuest)
    }

    private func call(state: String, recorded: Bool) -> CallSummaryDTO {
        CallSummaryDTO(
            callId: "call", parentId: "parent", state: state, timeSlot: nil,
            startedAt: Date(), endedAt: Date(), durationSec: 30, recorded: recorded, parentSpeechSec: nil
        )
    }
}
