//
//  UsageEventLogTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 이용 기록(앱 이벤트) 서버·앱 약속(2026-11-24): 기기에 쌓기·묶어 보내기·응답별 처리,
/// 로그인 전 단계(`onboarding_step`)와 하루 첫 실행(`app_open`).
@MainActor
struct UsageEventLogTests {
    // MARK: - 쌓기·보내기

    @Test func eventFollowsContractAndGoesToEventsWithLogin() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage

        usage.record(.reportView(.direct, subjectId: "mom"), using: fixture.environment)
        let event = try #require(usage.pendingEvents.first)
        #expect(event.name == "report_view")
        #expect(event.platform == "IOS")
        #expect(event.code == "DIRECT")
        #expect(event.subjectId == "mom")
        #expect(event.callId == nil)
        #expect(event.id == event.id.lowercased())
        #expect(UUID(uuidString: event.id) != nil)
        #expect(event.at.hasSuffix("Z"))
        #expect(Date.fromCollogTimestamp(event.at) != nil)
        #expect(event.appVersion.wholeMatch(of: /.+ \(.+\)/) != nil)
        #expect(event.appVersion.count <= 40)

        await usage.flush(using: fixture.environment)
        let request = try #require(server.requests.first)
        #expect(request.path == "/v1/events")
        #expect(request.method == "POST")
        #expect(request.authorization == "Bearer fixture-token")
        #expect(request.events.count == 1)
        #expect(request.events.first?["name"] as? String == "report_view")
        #expect(request.events.first?["subjectId"] as? String == "mom")
        #expect(request.events.first?["appVersion"] as? String == event.appVersion)
        #expect(usage.pendingEvents.isEmpty)
    }

    /// 서버는 `code`가 없어야 하는 이벤트(`app_open`·`incoming_call_shown`)에 값이 있으면 그 줄을 버린다.
    @Test func eventsWithoutACodeSendNoCodeField() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        usage.appDidBecomeActive(using: fixture.environment)
        usage.record(.incomingCallShown(callId: "call"), using: fixture.environment)

        await usage.flush(using: fixture.environment)
        let events = try #require(server.requests.first?.events)
        #expect(events.map { $0["name"] as? String } == ["app_open", "incoming_call_shown"])
        #expect(events.allSatisfy { $0["code"] == nil && $0["subjectId"] == nil })
        #expect(events.first?["callId"] == nil)
        #expect(events.last?["callId"] as? String == "call")
    }

    @Test(arguments: [EventServer.Failure.offline, .status(500), .status(503)])
    func connectionAndServerErrorsKeepEventsForNextTime(failure: EventServer.Failure) async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        server.failure = failure
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        usage.record(.appOpen, using: fixture.environment)

        await usage.flush(using: fixture.environment)
        #expect(server.requests.count == 1)
        #expect(usage.pendingEvents.count == 1)

        server.failure = nil
        await usage.flush(using: fixture.environment)
        #expect(server.requests.count == 2)
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test func unauthorizedKeepsEventsUntilTheSameUserLogsInAgain() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        server.failure = .status(401)
        fixture.respond = { request in
            if request.url?.path == "/v1/auth/refresh" { return (401, "{}") }
            return try server.respond(request)
        }
        let usage = fixture.environment.usage
        usage.record(.appOpen, using: fixture.environment)

        await usage.flush(using: fixture.environment)
        #expect(!fixture.environment.session.isAuthenticated)
        #expect(usage.pendingEvents.count == 1)

        server.failure = nil
        try fixture.signIn(as: "me")
        await usage.flush(using: fixture.environment)
        #expect(server.requests.count == 2)
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test(arguments: [400, 404, 422, 429])
    func otherClientErrorsDropTheBatch(status: Int) async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        server.failure = .status(status)
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        usage.record(.appOpen, using: fixture.environment)

        await usage.flush(using: fixture.environment)
        #expect(server.requests.count == 1)
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test func keepsOnlyTheNewest200() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let usage = fixture.environment.usage
        for index in 0..<205 {
            usage.record(.incomingCallShown(callId: "call-\(index)"), using: fixture.environment)
        }
        #expect(usage.pendingEvents.count == UsageEventLog.capacity)
        #expect(usage.pendingEvents.first?.callId == "call-5")
        #expect(usage.pendingEvents.last?.callId == "call-204")
    }

    @Test func sendsInBatchesOfFifty() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        for index in 0..<120 {
            usage.record(.incomingCallShown(callId: "call-\(index)"), using: fixture.environment)
        }

        await usage.flush(using: fixture.environment)
        #expect(server.requests.map(\.events.count) == [50, 50, 20])
        #expect(server.requests.first?.events.first?["callId"] as? String == "call-0")
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test func signOutClearsQueuedEvents() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (204, "") }
        let usage = fixture.environment.usage
        usage.record(.appOpen, using: fixture.environment)

        await fixture.environment.signOut()
        #expect(usage.pendingEvents.isEmpty)
        #expect(!fixture.paths.contains { $0.hasPrefix("/v1/events") })
    }

    @Test func guestModeRecordsNothing() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.environment.settings.isGuestMode = true
        let usage = fixture.environment.usage

        usage.record(.reportView(.direct, subjectId: nil), using: fixture.environment)
        usage.appDidBecomeActive(using: fixture.environment)
        usage.recordOnboardingStep(from: .launching, to: .login, using: fixture.environment)
        usage.recordOnboardingStep(from: .login, to: .ready, using: fixture.environment)
        await usage.flush(using: fixture.environment)

        #expect(usage.pendingEvents.isEmpty)
        #expect(fixture.paths.isEmpty)
    }

    @Test func sendsOnlyTheSignedInUsersEvents() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        usage.record(.incomingCallShown(callId: "mine"), using: fixture.environment)

        try fixture.signIn(as: "other")
        usage.record(.incomingCallShown(callId: "theirs"), using: fixture.environment)
        await usage.flush(using: fixture.environment)
        #expect(server.requests.count == 1)
        #expect(server.requests.first?.events.map { $0["callId"] as? String } == ["theirs"])
        #expect(usage.pendingEvents.map(\.callId) == ["mine"])

        try fixture.signIn(as: "me")
        await usage.flush(using: fixture.environment)
        #expect(server.requests.last?.events.map { $0["callId"] as? String } == ["mine"])
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test func signedOutRecordsNoLoggedInEvents() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.environment.session.signOut()
        let usage = fixture.environment.usage
        usage.record(.reportView(.direct, subjectId: nil), using: fixture.environment)
        usage.appDidBecomeActive(using: fixture.environment)
        #expect(usage.pendingEvents.isEmpty)
    }

    // MARK: - onboarding_step

    @Test func onboardingScreensMapToContractStepNames() {
        let code = UsageEventLog.onboardingCode
        #expect(code(.launching, .onboarding) == .welcome)
        #expect(code(.onboarding, .login) == .login)
        #expect(code(.login, .invitation) == .inviteCode)
        #expect(code(.invitation, .consent) == .aiConsent)
        #expect(code(.consent, .profile) == .conditions)
        #expect(code(.profile, .ready) == .done)
        #expect(code(.login, .ready) == .done)
        // 이미 가입한 사람이 앱을 열어 바로 홈으로 가면 단계가 아니다
        #expect(code(.launching, .ready) == nil)
        #expect(code(.ready, .launching) == nil)
    }

    @Test func stepsBeforeLoginGoAnonymouslyAndEachStepOncePerInstall() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        let server = EventServer()
        fixture.respond = { request in try server.respond(request) }
        let usage = fixture.environment.usage
        fixture.environment.session.signOut()

        usage.recordOnboardingStep(from: .launching, to: .onboarding, using: fixture.environment)
        usage.recordOnboardingStep(from: .onboarding, to: .login, using: fixture.environment)
        usage.recordOnboardingStep(from: .launching, to: .login, using: fixture.environment)
        #expect(usage.pendingEvents.map(\.code) == ["WELCOME", "LOGIN"])

        try fixture.signIn(as: "me")
        usage.recordOnboardingStep(from: .login, to: .consent, using: fixture.environment)
        usage.recordOnboardingStep(from: .consent, to: .profile, using: fixture.environment)
        usage.recordOnboardingStep(from: .profile, to: .ready, using: fixture.environment)
        await usage.flush(using: fixture.environment)

        #expect(server.requests.map(\.path) == ["/v1/events/anonymous", "/v1/events"])
        #expect(server.requests.first?.authorization == nil)
        #expect(server.requests.first?.events.map { $0["code"] as? String } == ["WELCOME", "LOGIN"])
        #expect(server.requests.first?.events.allSatisfy { $0["name"] as? String == "onboarding_step" } == true)
        #expect(server.requests.last?.authorization == "Bearer fixture-token")
        #expect(server.requests.last?.events.map { $0["code"] as? String } == ["AI_CONSENT", "CONDITIONS", "DONE"])

        // 로그아웃해서 쌓인 것을 지워도 이미 지난 단계는 다시 남기지 않는다(설치당 한 번)
        usage.clear()
        fixture.environment.session.signOut()
        usage.recordOnboardingStep(from: .ready, to: .login, using: fixture.environment)
        #expect(usage.pendingEvents.isEmpty)
    }

    @Test func stepsAfterLoginNeedALoggedInUser() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.environment.session.signOut()
        let usage = fixture.environment.usage
        usage.recordOnboardingStep(from: .login, to: .consent, using: fixture.environment)
        #expect(usage.pendingEvents.isEmpty)

        try fixture.signIn(as: "me")
        usage.recordOnboardingStep(from: .login, to: .consent, using: fixture.environment)
        #expect(usage.pendingEvents.map(\.code) == ["AI_CONSENT"])
    }

    // MARK: - app_open

    @Test func appOpenOncePerSeoulDay() throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        var clock = seoul(2026, 11, 24, hour: 9)
        let usage = UsageEventLog(defaults: fixture.defaults, sendsAutomatically: false, now: { clock })

        usage.appDidBecomeActive(using: fixture.environment)
        usage.appDidBecomeActive(using: fixture.environment)
        clock = seoul(2026, 11, 24, hour: 23, minute: 59)
        usage.appDidBecomeActive(using: fixture.environment)
        #expect(usage.pendingEvents.map(\.name) == ["app_open"])

        // UTC 로는 같은 날(15:01Z)이지만 서울 날짜가 바뀌었다
        clock = seoul(2026, 11, 25, hour: 0, minute: 1)
        usage.appDidBecomeActive(using: fixture.environment)
        #expect(usage.pendingEvents.map(\.name) == ["app_open", "app_open"])
        #expect(usage.pendingEvents.last?.at == "2026-11-24T15:01:00Z")
        #expect(usage.pendingEvents.allSatisfy { $0.code == nil && $0.subjectId == nil && $0.callId == nil })
    }

    private func seoul(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        HealthDailyCalculator.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}

extension TestEnvironment {
    func signIn(as userId: String) throws {
        try environment.session.apply(TokenResponse(
            accessToken: "fixture-token", refreshToken: "fixture-refresh",
            user: APIUser(id: userId, role: "CHILD", name: "Tester", phone: nil, familyId: "family")
        ))
    }
}

/// `/v1/events`·`/v1/events/anonymous`를 받는 가짜 서버. 받은 요청을 남긴다.
@MainActor
final class EventServer {
    enum Failure: Sendable, CustomTestStringConvertible {
        case offline
        case status(Int)

        var testDescription: String {
            switch self {
            case .offline: "연결 오류"
            case let .status(code): "\(code)"
            }
        }
    }

    struct Received {
        let path: String
        let method: String?
        let authorization: String?
        let events: [[String: Any]]
    }

    var failure: Failure?
    private(set) var requests: [Received] = []

    func respond(_ request: URLRequest) throws -> (Int, String) {
        let path = request.url?.path ?? ""
        guard path.hasPrefix("/v1/events") else {
            Issue.record("Unexpected request \(path)")
            throw URLError(.unsupportedURL)
        }
        let events = (Self.body(request)["events"] as? [[String: Any]]) ?? []
        requests.append(Received(
            path: path, method: request.httpMethod,
            authorization: request.value(forHTTPHeaderField: "Authorization"), events: events
        ))
        switch failure {
        case .offline: throw URLError(.notConnectedToInternet)
        case let .status(code): return (code, #"{"code":"FAILED","message":"fixture"}"#)
        case nil: return (200, #"{"accepted":\#(events.count)}"#)
        }
    }

    /// URLProtocol 은 본문을 스트림으로 넘긴다.
    private static func body(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
