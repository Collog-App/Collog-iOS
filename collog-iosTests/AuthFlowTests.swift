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
    @Test func parentWithoutFamilyCanEnterInvitation() async throws {
        let fixture = try TestEnvironment(familyId: nil)
        defer { fixture.cleanUp() }
        let model = AuthFlowViewModel()
        await model.resolve(using: fixture.environment)
        #expect(model.step == .invitation)
        #expect(fixture.paths.isEmpty)
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
}
