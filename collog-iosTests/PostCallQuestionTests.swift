//
//  PostCallQuestionTests.swift
//  collog-ios
//

import CallKit
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
        let question = try #require(center.postCallQuestion)
        #expect(question.callId == "call")
        #expect(question.peerId == "mom")
        #expect(question.peerName == "엄마")
        #expect(question.ownerId == "me")

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

    /// 내가 끊는 길(CallKit 의 통화 종료 요청)에서도 묻는다.
    @Test func callerHangingUpIsAsked() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        let call = connectedOutgoing(id: "call", questions: ["질문"])
        center.activeCall = call

        center.provider(center.provider, perform: EndCallActionStub(call: call.uuid))
        #expect(center.activeCall == nil)
        #expect(center.postCallQuestion?.callId == "call")
        await fixture.waitForRequests(["/v1/calls/call/end"])
    }

    @Test func startingANewCallRemovesTheQuestion() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "call", questions: ["질문"])
        center.finishRemoteCall()
        #expect(center.postCallQuestion != nil)

        center.startOutgoingCall(calleeId: "mom", name: "엄마", questions: [])
        #expect(center.postCallQuestion == nil)
        // 시험에서는 실제로 걸지 않는다(마이크 권한을 받은 뒤 이 통화가 아니면 멈춘다)
        center.pendingOutgoing = nil
    }

    /// 화면을 잠근 채 통화하고 한참 뒤 앱을 열면 묻지 않는다.
    @Test func questionExpiresTwoMinutesAfterTheCall() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = connectedOutgoing(id: "call", questions: ["질문"])
        center.offerPostCallQuestion()
        let endedAt = try #require(center.postCallQuestion?.endedAt)

        let later = endedAt.addingTimeInterval(CallCenter.PostCallQuestion.lifetime + 1)

        // 화면은 그리기 전에 만료를 본다(앱이 앞으로 와 만료를 지우기 전의 첫 화면에도 뜨지 않게)
        #expect(center.visiblePostCallQuestion(now: endedAt.addingTimeInterval(60))?.callId == "call")
        #expect(center.visiblePostCallQuestion(now: later) == nil)

        // 앱이 앞으로 올 때 지운다
        center.expirePostCallQuestion(now: endedAt.addingTimeInterval(60))
        #expect(center.postCallQuestion != nil)
        center.expirePostCallQuestion(now: later)
        #expect(center.postCallQuestion == nil)
        #expect(fixture.environment.usage.pendingEvents.isEmpty)
    }

    private func connectedOutgoing(id: String, questions: [String]) -> CallCenter.ActiveCall {
        .fixture(id: id, direction: .outgoing, phase: .active, questions: questions, connected: true)
    }
}

/// 시스템 CallKit 거래 없이 위임 메서드를 부를 때 쓰는 통화 종료 요청.
private final class EndCallActionStub: CXEndCallAction {
    override func fulfill() {}
    override func fail() {}
}
