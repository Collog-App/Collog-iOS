//
//  AuthFlowTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Testing
@testable import collog_ios

@MainActor
struct AuthFlowTests {
    @Test(arguments: [("PARENT", nil), ("CHILD", "solo-family")] as [(String, String?)])
    func signInOffersOptionalInvitationToAnyoneAlone(role: String, familyId: String?) async throws {
        let fixture = try TestEnvironment(role: role, familyId: familyId)
        defer { fixture.cleanUp() }
        let model = AuthFlowViewModel()
        fixture.environment.session.signOut()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .login)

        try signIn(fixture, role: role, familyId: familyId)
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true { return (200, members(others: [])) }
            return (200, fixture.consent(granted: false))
        }
        await model.resolve(using: fixture.environment)
        #expect(model.step == .invitation)

        model.completeInvitation()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .ready)
    }

    @Test func connectedUserSkipsInvitationAfterSignIn() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let model = AuthFlowViewModel()
        fixture.environment.session.signOut()
        await model.resolve(using: fixture.environment)
        try signIn(fixture, role: "CHILD", familyId: "family")
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true { return (200, members(others: ["parent"])) }
            return (200, fixture.consent(granted: false))
        }
        await model.resolve(using: fixture.environment)
        #expect(model.step == .ready)
        #expect(fixture.paths == ["/v1/families/family/members", "/v1/consents/me"])
    }

    @Test func storedSessionWithoutFamilyIsNotForcedToEnterCode() async throws {
        let fixture = try TestEnvironment(familyId: nil)
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, fixture.consent(granted: false)) }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .ready)
        #expect(fixture.paths == ["/v1/consents/me"])
    }

    @Test func childWithGrantedConsentSetsUpOwnProfile() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            if request.url?.path.contains("consent") == true { return (200, fixture.consent()) }
            return (200, #"{"parentId":"me","conditions":[],"isCompleted":false,"updatedAt":null}"#)
        }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .profile)
        #expect(fixture.paths.last == "/v1/parents/me/profile")
    }

    @Test(arguments: ["PARENT", "CHILD"])
    func outdatedConsentRequiresPermissionForBothRoles(role: String) async throws {
        let fixture = try TestEnvironment(role: role)
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, fixture.consent(current: false)) }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .consent)
        #expect(fixture.paths.count == 1)
    }

    @Test func declinedAnalysisDoesNotBlockAppAccess() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, fixture.consent(granted: false)) }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .ready)
        #expect(fixture.paths.count == 1)
    }

    @Test(arguments: [true, false])
    func emptyHealthProfileUsesCompletionFlag(completed: Bool) async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            if request.url?.path.contains("consent") == true { return (200, fixture.consent()) }
            return (200, """
            {"parentId":"me","conditions":[],"isCompleted":\(completed),"updatedAt":null}
            """)
        }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == (completed ? .ready : .profile))
        #expect(fixture.paths.count == 2)
    }

    @Test func consentFailureKeepsPermissionRequired() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (503, "{}") }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .consent)
    }

    private func signIn(_ fixture: TestEnvironment, role: String, familyId: String?) throws {
        try fixture.environment.session.apply(TokenResponse(
            accessToken: "fixture-token", refreshToken: "fixture-refresh",
            user: APIUser(id: "me", role: role, name: "Tester", phone: nil, familyId: familyId)
        ))
    }

    private func members(others: [String]) -> String {
        let rows = (others + ["me"]).map {
            """
            {"memberId":"member-\($0)","userId":"\($0)","name":"\($0)","relation":"",
            "status":"ACTIVE","role":"CHILD"}
            """
        }
        return "{\"members\":[\(rows.joined(separator: ","))]}"
    }
}
