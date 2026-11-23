//
//  FamilyMemberRemovalTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

/// 가족 구성원 삭제·초대 취소: 대기 중 초대는 누구나, 연결된 구성원은 가족을 만든 사람이나 본인(나가기)만.
@MainActor
struct FamilyMemberRemovalTests {
    @Test
    func pendingInvitationCanBeRemovedByAnyMember() {
        #expect(resolve(memberUserId: nil) == .invitation)
        #expect(FamilyMemberRemoval.invitation.confirmationTitle(name: "어머니") == "어머니님에게 보낸 초대를 삭제할까요?")
        #expect(FamilyMemberRemoval.invitation.confirmTitle == "삭제")
    }

    @Test
    func connectedMemberFollowsServerPermission() {
        #expect(resolve(memberUserId: "parent") == .member)
        #expect(resolve(canRemove: false, memberUserId: "parent") == nil)
        #expect(FamilyMemberRemoval.member.confirmationTitle(name: "어머니") == "어머니님을 가족에서 삭제할까요?")
        #expect(FamilyMemberRemoval.member.actionTitle == "삭제")
    }

    @Test
    func ownRowOffersLeavingOnlyWhenSomeoneElseIsConnected() {
        #expect(resolve(memberUserId: "me") == .leave)
        #expect(resolve(memberUserId: "me", hasOtherConnectedMember: false) == nil)
        #expect(FamilyMemberRemoval.leave.actionTitle == "가족에서 나가기")
        #expect(FamilyMemberRemoval.leave.confirmTitle == "나가기")
    }

    @Test
    func guestNeverSeesRemoval() {
        #expect(resolve(isGuest: true, memberUserId: nil) == nil)
        #expect(resolve(isGuest: true, memberUserId: "parent") == nil)
    }

    @Test
    func membersDecodeServerRemovalPermissionWhenPresent() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in
            (200, """
            {"members":[
              {"memberId":"a","userId":"parent","name":"A","relation":"MOTHER","status":"ACTIVE","canRemove":false},
              {"memberId":"b","userId":null,"name":"B","relation":"FATHER","status":"INVITED","canRemove":true},
              {"memberId":"c","userId":"me","name":"C","relation":"","status":"ACTIVE"}
            ],"canInvite":true}
            """)
        }
        let members = try await fixture.environment.api.members(familyId: "family")
        #expect(members.map(\.canRemove) == [false, true, nil])
    }

    @Test
    func removalSendsDeleteForThatMember() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        var methods: [String] = []
        var queries: [String?] = []
        fixture.respond = { request in
            methods.append(request.httpMethod ?? "")
            queries.append(request.url?.query)
            return (204, "")
        }
        try await fixture.environment.api.removeFamilyMember(familyId: "family", memberId: "member-1")
        #expect(fixture.paths == ["/v1/families/family/members/member-1"])
        #expect(methods == ["DELETE"])
        // 연결된 구성원 삭제·나가기는 조건 없이 보낸다
        #expect(queries == [nil])
    }

    @Test
    func cancellingAnInvitationOnlyRemovesItWhileItIsStillPending() async throws {
        #expect(FamilyMemberRemoval.invitation.isPendingOnly)
        #expect(!FamilyMemberRemoval.member.isPendingOnly)
        #expect(!FamilyMemberRemoval.leave.isPendingOnly)

        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        var queries: [String?] = []
        fixture.respond = { request in
            queries.append(request.url?.query)
            return (204, "")
        }
        try await fixture.environment.api.removeFamilyMember(
            familyId: "family", memberId: "member-1", pendingOnly: FamilyMemberRemoval.invitation.isPendingOnly
        )
        #expect(fixture.paths == ["/v1/families/family/members/member-1"])
        #expect(queries == ["pendingOnly=true"])
    }

    @Test
    func invitationAcceptedInTheMeantimeKeepsTheMemberAndShowsServerMessage() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in
            (409, #"{"code":"CONFLICT","message":"이미 수락한 초대예요. 가족 목록을 다시 확인해주세요"}"#)
        }
        do {
            try await fixture.environment.api.removeFamilyMember(
                familyId: "family", memberId: "member-1", pendingOnly: true
            )
            Issue.record("expected the server to refuse")
        } catch {
            #expect(FamilyMemberRemoval.failureText(for: error) == "이미 수락한 초대예요. 가족 목록을 다시 확인해주세요")
        }
    }

    @Test
    func rowThatIsAlreadyGoneIsNotReportedAsAFailure() {
        let gone = APIError.server(status: 404, code: "NOT_FOUND", message: "가족 구성원을 찾을 수 없습니다")
        #expect(gone.isNotFound)
        #expect(FamilyMemberRemoval.failureText(for: gone) == nil)
        let refused = APIError.server(status: 403, code: "SCOPE_DENIED", message: "가족을 만든 사람이나 본인만 내보낼 수 있어요")
        #expect(!refused.isNotFound)
        #expect(FamilyMemberRemoval.failureText(for: refused) == "가족을 만든 사람이나 본인만 내보낼 수 있어요")
        #expect(FamilyMemberRemoval.failureText(for: APIError.transport("연결 실패")) == "연결 실패")
    }

    @Test
    func refusedRemovalKeepsServerMessage() async throws {
        let fixture = try TestEnvironment()
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (403, #"{"code":"FORBIDDEN","message":"가족을 만든 사람이나 본인만 내보낼 수 있어요"}"#) }
        do {
            try await fixture.environment.api.removeFamilyMember(familyId: "family", memberId: "member-1")
            Issue.record("expected the server to refuse")
        } catch {
            #expect((error as? APIError)?.isForbidden == true)
            #expect(error.localizedDescription == "가족을 만든 사람이나 본인만 내보낼 수 있어요")
        }
    }

    // MARK: - 가족에서 나갔거나 삭제된 뒤

    @Test
    func revokedFamilyFallsBackToNoFamily() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            let path = request.url?.path ?? ""
            if path == "/v1/families" { return (200, #"{"families":[]}"#) }
            return (403, #"{"code":"FORBIDDEN","message":"가족 접근 권한이 없습니다"}"#)
        }
        let family = fixture.environment.family
        await family.refresh(using: fixture.environment)

        #expect(fixture.environment.session.familyId == nil)
        #expect(fixture.credentials.response?.user.familyId == nil)
        #expect(fixture.environment.session.isAuthenticated)
        #expect(family.loadError == nil)
        #expect(family.contacts.isEmpty)
        // 다시 초대 코드를 넣을 수 있다
        #expect(family.canEnterInvitationCode(using: fixture.environment))
        #expect(fixture.paths == ["/v1/families/family/members", "/v1/families"])
    }

    @Test
    func revokedFamilyMovesToRemainingFamily() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            switch request.url?.path ?? "" {
            case "/v1/families":
                (200, #"{"families":[{"familyId":"other","name":"다른 가족"}]}"#)
            case "/v1/families/other/members":
                (200, #"{"members":[{"memberId":"me","userId":"me","name":"Me","relation":"","status":"ACTIVE"}]}"#)
            default:
                (403, #"{"code":"FORBIDDEN","message":"가족 접근 권한이 없습니다"}"#)
            }
        }
        await fixture.environment.family.refresh(using: fixture.environment)

        #expect(fixture.environment.session.familyId == "other")
        #expect(fixture.environment.family.loadError == nil)
        #expect(fixture.environment.family.memberUserIds == ["me"])
    }

    @Test
    func forbiddenFamilyThatIsStillListedStaysAnError() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { request in
            if request.url?.path == "/v1/families" {
                return (200, #"{"families":[{"familyId":"family","name":"우리 가족"}]}"#)
            }
            return (403, #"{"code":"FORBIDDEN","message":"가족 접근 권한이 없습니다"}"#)
        }
        await fixture.environment.family.refresh(using: fixture.environment)

        #expect(fixture.environment.session.familyId == "family")
        #expect(fixture.environment.family.loadError == "가족 접근 권한이 없습니다")
    }

    @Test
    func otherFailuresDoNotDropTheFamily() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        fixture.respond = { _ in (503, "{}") }
        await fixture.environment.family.refresh(using: fixture.environment)

        #expect(fixture.environment.session.familyId == "family")
        #expect(fixture.paths == ["/v1/families/family/members"])
    }

    @Test
    func sessionOnlyDropsTheFamilyItWasAskedAbout() throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let session = fixture.environment.session
        let other = FamilySummary(familyId: "other", name: "다른 가족")

        #expect(try !session.dropRevokedFamily("stale", available: []))
        #expect(try !session.dropRevokedFamily("family", available: [FamilySummary(familyId: "family", name: "")]))
        #expect(session.familyId == "family")
        #expect(try session.dropRevokedFamily("family", available: [other]))
        #expect(session.familyId == "other")
        #expect(try session.dropRevokedFamily("other", available: []))
        #expect(session.familyId == nil)
    }

    private func resolve(
        isGuest: Bool = false, canRemove: Bool = true, memberUserId: String?, hasOtherConnectedMember: Bool = true
    ) -> FamilyMemberRemoval? {
        .resolve(
            isGuest: isGuest, canRemove: canRemove, memberUserId: memberUserId, userId: "me",
            hasOtherConnectedMember: hasOtherConnectedMember
        )
    }
}
