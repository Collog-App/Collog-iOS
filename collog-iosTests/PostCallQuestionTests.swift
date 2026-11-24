//
//  PostCallQuestionTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 통화 뒤 한 줄 질문(이용 기록 `post_call_answer`): 건 사람이 연결된 통화를 마쳤고 추천 질문이 보였을 때만, 통화마다 한 번.
@MainActor
struct PostCallQuestionTests {
    @Test func callerIsAskedOnceAfterAConnectedCallWithQuestions() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "call", questions: ["요즘 잠은 잘 주무세요?"])

        center.finishRemoteCall()
        #expect(center.activeCall == nil)
        #expect(center.postCallQuestion == CallCenter.PostCallQuestion(
            callId: "call", peerId: "mom", peerName: "엄마", ownerId: "me"
        ))

        center.answerPostCallQuestion(.notSeen)
        center.answerPostCallQuestion(.yes)
        #expect(center.postCallQuestion == nil)
        let events = fixture.environment.usage.pendingEvents
        #expect(events.count == 1)
        #expect(events.first?.name == "post_call_answer")
        #expect(events.first?.code == "NOT_SEEN")
        #expect(events.first?.subjectId == "mom")
        #expect(events.first?.callId == "call")
    }

    @Test func closingWithoutAnAnswerRecordsNothing() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "call", questions: ["질문"])
        center.offerPostCallQuestion()
        #expect(center.postCallQuestion != nil)

        center.dismissPostCallQuestion()
        #expect(center.postCallQuestion == nil)
        #expect(fixture.environment.usage.pendingEvents.isEmpty)
    }

    @Test func questionIsNotAskedForCallsThatDoNotQualify() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)

        // 받는 쪽
        let incoming = CallCenter.ActiveCall.fixture(
            id: "incoming", direction: .incoming, phase: .active, questions: ["질문"], connected: true
        )
        // 연결되지 않은 통화(상대가 안 받음·거절)
        let unanswered = CallCenter.ActiveCall.fixture(
            id: "unanswered", direction: .outgoing, phase: .ringing, questions: ["질문"]
        )
        // 추천 질문이 없던 통화
        let noQuestions = connectedOutgoing(id: "no-questions", questions: [])
        for candidate in [incoming, unanswered, noQuestions] {
            center.callOwnerId = "me"
            center.activeCall = candidate
            center.finishRemoteCall()
            #expect(center.postCallQuestion == nil, "\(candidate.id)")
        }

        // 실패로 끝난 통화
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "failed", questions: ["질문"])
        center.finishRemoteCall(reason: .failed)
        #expect(center.postCallQuestion == nil)

        // 둘러보기
        fixture.environment.settings.isGuestMode = true
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "guest", questions: ["질문"])
        center.finishRemoteCall()
        #expect(center.postCallQuestion == nil)
        #expect(fixture.environment.usage.pendingEvents.isEmpty)
    }

    @Test func questionGoesAwayWhenTheAccountChanges() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "call", questions: ["질문"])
        center.offerPostCallQuestion()

        center.sessionDidChange()
        #expect(center.postCallQuestion != nil)
        try fixture.signIn(as: "other")
        center.sessionDidChange()
        #expect(center.postCallQuestion == nil)
    }

    private func connectedOutgoing(id: String, questions: [String]) -> CallCenter.ActiveCall {
        .fixture(id: id, direction: .outgoing, phase: .active, questions: questions, connected: true)
    }
}
