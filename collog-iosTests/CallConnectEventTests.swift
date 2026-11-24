//
//  CallConnectEventTests.swift
//  collog-ios
//

import CallKit
import Foundation
import LiveKit
import Testing
@testable import collog_ios

/// 이용 기록 `call_connect_failed`: 한 번도 연결되지 못한 통화가 실패로 끝났을 때만, 실패 갈래별 코드로 남는다.
@MainActor
struct CallConnectEventTests {
    @Test func connectFailureCodesFollowTheFailure() {
        #expect(CallConnectFailure(APIError.transport("offline")) == .network)
        #expect(CallConnectFailure(URLError(.timedOut)) == .network)
        #expect(CallConnectFailure(APIError.unauthenticated) == .token)
        #expect(CallConnectFailure(APIError.server(status: 502, code: "F", message: "")) == .server)
        #expect(CallConnectFailure(APIError.server(status: 409, code: "BUSY", message: "")) == .server)
        #expect(CallConnectFailure(APIError.decoding("x")) == .server)
        #expect(CallConnectFailure(LiveKitError(.validation)) == .token)
        #expect(CallConnectFailure(LiveKitError(.insufficientPermissions)) == .token)
        #expect(CallConnectFailure(LiveKitError(.network)) == .network)
        #expect(CallConnectFailure(LiveKitError(.timedOut)) == .network)
        #expect(CallConnectFailure(LiveKitError(.joinFailure)) == .server)
        #expect(CallConnectFailure(LiveKitError(.serverShutdown)) == .server)
        #expect(CallConnectFailure(LiveKitError(.deviceAccessDenied)) == .microphonePermission)
        #expect(CallConnectFailure(LiveKitError(.audioEngine)) == .other)
        #expect(CallConnectFailure(CancellationError()) == .other)
        #expect(CallConnectFailure.microphonePermission.rawValue == "MIC_PERMISSION")
    }

    @Test func callThatNeverConnectedRecordsItsFailure() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.callOwnerId = "me"
        center.activeCall = .fixture(id: "incoming", direction: .incoming, phase: .ringing)

        center.failCall(
            uuid: try #require(center.activeCall?.uuid), message: "마이크", microphone: true,
            failure: .microphonePermission
        )
        let event = try #require(fixture.environment.usage.pendingEvents.first)
        #expect(event.name == "call_connect_failed")
        #expect(event.code == "MIC_PERMISSION")
        #expect(event.callId == "incoming")
        #expect(center.activeCall == nil)
        await fixture.waitForRequests(["/v1/calls/incoming/decline"])
    }

    /// 방해 금지·집중 모드·차단 목록처럼 시스템이 걸러 낸 수신은 연결 실패가 아니다.
    @Test func incomingCallsFilteredBySystemAreNotConnectFailures() async throws {
        let filtered: [CXErrorCodeIncomingCallError.Code] = [
            .filteredByDoNotDisturb, .filteredByBlockList,
            .filteredDuringRestrictedSharingMode, .filteredBySensitiveParticipants
        ]
        for code in filtered {
            #expect(CallConnectFailure(incomingCallReport: CXErrorCodeIncomingCallError(code)) == nil)
        }
        #expect(CallConnectFailure(incomingCallReport: CXErrorCodeIncomingCallError(.unknown)) == .other)
        #expect(CallConnectFailure(incomingCallReport: URLError(.unknown)) == .other)

        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)
        center.activeCall = .fixture(id: "dnd", direction: .incoming, phase: .ringing)
        center.failCall(
            uuid: try #require(center.activeCall?.uuid), message: "x",
            failure: CallConnectFailure(incomingCallReport: CXErrorCodeIncomingCallError(.filteredByDoNotDisturb))
        )
        #expect(fixture.environment.usage.pendingEvents.isEmpty)
        await fixture.waitForRequests(["/v1/calls/dnd/decline"])
    }

    @Test func hangUpsAndDropsAfterConnectingAreNotConnectFailures() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let center = CallCenter(environment: fixture.environment)

        // 스스로 끊으려다 CallKit 이 거절한 경우
        center.activeCall = .fixture(id: "cancelled", direction: .outgoing, phase: .connecting)
        center.failCall(uuid: try #require(center.activeCall?.uuid), message: "x", failure: nil)
        // 연결된 뒤 끊긴 통화
        let connected = CallCenter.ActiveCall.fixture(
            id: "dropped", direction: .outgoing, phase: .active, connected: true
        )
        center.activeCall = connected
        center.failCall(uuid: connected.uuid, message: "x", failure: .network)
        // 상대가 끊음·안 받음·거절(서버가 통화를 끝냄)
        center.activeCall = .fixture(id: "declined", direction: .outgoing, phase: .ringing)
        center.finishRemoteCall()
        center.activeCall = .fixture(id: "unanswered", direction: .incoming, phase: .ringing)
        center.finishRemoteCall(reason: .unanswered)

        #expect(fixture.environment.usage.pendingEvents.isEmpty)
        await fixture.waitForRequests(["/v1/calls/cancelled/end", "/v1/calls/dropped/end"])
    }
}

extension CallCenter.ActiveCall {
    static func fixture(
        id: String, direction: Direction, phase: CallPhase, questions: [String] = [], connected: Bool = false
    ) -> Self {
        var call = Self(
            id: id, uuid: UUID(), direction: direction,
            peerId: "mom", peerName: "엄마", phase: phase, questions: questions
        )
        call.wasConnected = connected
        return call
    }
}

extension TestEnvironment {
    /// 통화를 정리하며 띄운 서버 요청이 나갈 때까지 기다린다. 시험이 끝나 닫힌 세션에 요청을 만들면 시험 앱이 죽는다.
    func waitForRequests(_ expected: [String]) async {
        var attempts = 0
        while !expected.allSatisfy(paths.contains), attempts < 300 {
            attempts += 1
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(expected.allSatisfy(paths.contains))
    }
}
