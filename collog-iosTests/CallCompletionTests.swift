//
//  CallCompletionTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import CallKit
import Testing
@testable import collog_ios

@MainActor
struct CallCompletionTests {
    @Test
    func invalidatedActionRejectsResponsesBeforeSDKCompletionUpdates() {
        var count = 0
        let response = CallActionResponse(isComplete: { false }, fulfill: { count += 1 }, fail: { count += 1 })
        response.invalidate()
        response.fulfill()
        response.fail()
        #expect(count == 0)
    }

    @Test
    func systemActionCompletesThroughResponseAdapter() {
        let action = RecordingCallAction()
        let response = CallActionResponse(action: action)
        response.fulfill()
        response.fail()
        #expect(action.fulfillCount == 1)
        #expect(action.failCount == 0)
    }

    @Test
    func completedSystemActionRejectsLateResponses() async {
        var completed = false
        var fulfillCount = 0
        var failCount = 0
        let response = CallActionResponse(
            isComplete: { completed }, fulfill: { fulfillCount += 1 }, fail: { failCount += 1 }
        )
        completed = true
        let pending = Task { @MainActor in
            response.fail()
            response.fulfill()
        }
        await pending.value
        #expect(fulfillCount == 0)
        #expect(failCount == 0)
    }

    @Test
    func firstActionResponseWinsEvenBeforeSystemUpdatesCompletion() {
        var fulfillCount = 0
        var failCount = 0
        let response = CallActionResponse(
            isComplete: { false }, fulfill: { fulfillCount += 1 }, fail: { failCount += 1 }
        )
        response.fulfill()
        response.fail()
        response.fulfill()
        #expect(fulfillCount == 1)
        #expect(failCount == 0)
    }

    @Test
    func pushCompletionRunsOnceAcrossScheduledCallbacks() async {
        var count = 0
        let completion = IncomingPushCompletion { count += 1 }
        let first = Task { @MainActor in completion.finish() }
        let second = Task { @MainActor in completion.finish() }
        await first.value
        await second.value
        #expect(count == 1)
    }
}

private final class RecordingCallAction: CXAction {
    var fulfillCount = 0
    var failCount = 0

    override func fulfill() { fulfillCount += 1 }
    override func fail() { failCount += 1 }
}
