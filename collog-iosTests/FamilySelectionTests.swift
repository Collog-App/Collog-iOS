//
//  FamilySelectionTests.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Testing
@testable import collog_ios

@MainActor
struct FamilySelectionTests {
    @Test func contactSelectionSurvivesMemberReordering() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        var parents = ["first", "second"]
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true {
                return (200, members(parents: parents))
            }
            return (200, #"{"source":"fixture","questions":[]}"#)
        }
        let store = fixture.environment.family
        await store.refresh(using: fixture.environment)
        #expect(store.contacts.map(\.id) == parents)
        store.selectContact(try #require(store.contacts.last))
        parents.reverse()
        await store.refresh(using: fixture.environment)
        #expect(store.selectedContactId == "second")
        #expect(fixture.paths.last == "/v1/parents/second/daily-questions")
    }

    @Test func removedContactFallsBackToRemainingFamilyMember() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        var parents = ["first", "second"]
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true {
                return (200, members(parents: parents))
            }
            return (200, #"{"source":"fixture","questions":[]}"#)
        }
        let store = fixture.environment.family
        await store.refresh(using: fixture.environment)
        store.selectContact(try #require(store.contacts.last))
        parents = ["first"]
        await store.refresh(using: fixture.environment)
        #expect(store.selectedContactId == "first")
        #expect(fixture.paths.last == "/v1/parents/first/daily-questions")
    }

    @Test func switchingFamilyUpdatesRequestsWithoutLosingAuthentication() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (200, #"{"members":[]}"#) }
        try fixture.environment.session.joinFamily("another-family")
        await fixture.environment.family.refresh(using: fixture.environment)
        #expect(fixture.paths.first == "/v1/families/another-family/members")
        #expect(fixture.credentials.response?.user.familyId == "another-family")
        #expect(fixture.environment.session.isAuthenticated)
    }

    @Test func tokenRefreshPreservesChosenFamilyAcrossSessionRestore() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        try fixture.environment.session.joinFamily("chosen-family")
        fixture.respond = { request in
            #expect(request.url?.path == "/v1/auth/refresh")
            return (200, """
            {"accessToken":"new-token","refreshToken":"new-refresh",
            "user":{"id":"me","role":"CHILD","name":"Tester","phone":null,"familyId":"family"}}
            """)
        }
        let token = try await fixture.environment.session.refresh(
            using: fixture.environment.settings.resolvedBaseURL
        )
        #expect(token == "new-token")
        #expect(fixture.environment.session.familyId == "chosen-family")
        #expect(fixture.credentials.response?.user.familyId == "chosen-family")
        let restored = AuthSession(
            defaults: fixture.defaults, credentialStore: fixture.credentials,
            networkSession: fixture.networkSession
        )
        #expect(restored.familyId == "chosen-family")
        #expect(restored.accessToken == "new-token")
    }

    private func members(parents: [String]) -> String {
        let parents = parents.map {
            """
            {"memberId":"\($0)","userId":"\($0)","name":"Parent","relation":"PARENT",
            "status":"ACTIVE","role":"PARENT"}
            """
        }
        let excluded = [
            """
            {"memberId":"self","userId":"me","name":"Self","relation":"CHILD",
            "status":"ACTIVE","role":"CHILD"}
            """,
            """
            {"memberId":"sibling","userId":"sibling","name":"Sibling","relation":"CHILD",
            "status":"ACTIVE","role":"CHILD"}
            """,
            """
            {"memberId":"invited","userId":null,"name":"Invited","relation":"PARENT",
            "status":"INVITED","role":"PARENT"}
            """
        ]
        return "{\"members\":[\((parents + excluded).joined(separator: ","))]}"
    }
}
