//
//  FamilyInvitationAccessTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct FamilyInvitationAccessTests {
    @Test
    func anyoneCanInviteOnceServerAllowsIt() {
        #expect(FamilyInvitationAccess.canInvite(isGuest: false, hasFamily: true, serverAllowsInvitations: true))
        #expect(!FamilyInvitationAccess.canInvite(isGuest: false, hasFamily: true, serverAllowsInvitations: false))
    }

    @Test
    func userWithoutFamilyCanStartOneByInviting() {
        #expect(FamilyInvitationAccess.canInvite(isGuest: false, hasFamily: false, serverAllowsInvitations: false))
    }

    @Test
    func guestCannotInviteOrEnterCode() {
        #expect(!FamilyInvitationAccess.canInvite(isGuest: true, hasFamily: true, serverAllowsInvitations: true))
        #expect(!FamilyInvitationAccess.canEnterCode(isGuest: true, memberUserIds: [], userId: "me"))
    }

    @Test
    func aloneUserCanEnterCodeIncludingPendingInvitations() {
        #expect(FamilyInvitationAccess.canEnterCode(isGuest: false, memberUserIds: [], userId: "me"))
        #expect(FamilyInvitationAccess.canEnterCode(isGuest: false, memberUserIds: ["me", nil], userId: "me"))
    }

    @Test
    func connectedUserCannotEnterCode() {
        #expect(!FamilyInvitationAccess.canEnterCode(isGuest: false, memberUserIds: ["me", "parent"], userId: "me"))
    }

    // MARK: - 설정 맨 위·계정 정보의 「초대 코드 입력」

    @Test(arguments: ["PARENT", "CHILD"])
    func settingsOfferCodeEntryToAnyoneAloneRegardlessOfRole(role: String) async throws {
        let fixture = try TestEnvironment(role: role)
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        // 구성원 목록을 읽기 전에는 띄우지 않는다
        #expect(!family.canEnterInvitationCode(using: fixture.environment))

        fixture.respond = { _ in (200, members(["me", nil])) }
        await family.refresh(using: fixture.environment)
        #expect(family.memberUserIds == ["me", nil])
        #expect(family.canEnterInvitationCode(using: fixture.environment))
    }

    @Test
    func settingsHideCodeEntryOnceSomeoneIsConnected() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true { return (200, members(["me"])) }
            return (200, #"{"source":"fixture","questions":[]}"#)
        }
        await family.refresh(using: fixture.environment)
        #expect(family.canEnterInvitationCode(using: fixture.environment))

        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true { return (200, members(["me", "parent"])) }
            return (200, #"{"source":"fixture","questions":[]}"#)
        }
        await family.refresh(using: fixture.environment)
        #expect(!family.canEnterInvitationCode(using: fixture.environment))
    }

    @Test
    func userWithoutFamilyCanEnterCodeWithoutAnyRequest() async throws {
        let fixture = try TestEnvironment(role: "PARENT", familyId: nil)
        defer { fixture.cleanUp() }
        await fixture.environment.family.refresh(using: fixture.environment)
        #expect(fixture.environment.family.memberUserIds == [])
        #expect(fixture.environment.family.canEnterInvitationCode(using: fixture.environment))
        #expect(fixture.paths.isEmpty)
    }

    @Test
    func failedMemberLoadKeepsLastKnownAnswer() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        fixture.respond = { _ in (503, "{}") }
        await family.refresh(using: fixture.environment)
        #expect(family.memberUserIds == nil)
        #expect(!family.canEnterInvitationCode(using: fixture.environment))

        fixture.respond = { _ in (200, members(["me"])) }
        await family.refresh(using: fixture.environment)
        fixture.respond = { _ in (503, "{}") }
        await family.refresh(using: fixture.environment)
        #expect(family.canEnterInvitationCode(using: fixture.environment))
    }

    @Test
    func guestAndSignedOutNeverSeeCodeEntry() async throws {
        let fixture = try TestEnvironment(role: "CHILD", familyId: nil)
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        await family.refresh(using: fixture.environment)
        #expect(family.canEnterInvitationCode(using: fixture.environment))

        fixture.environment.settings.isGuestMode = true
        await family.refresh(using: fixture.environment)
        #expect(family.memberUserIds == nil)
        #expect(!family.canEnterInvitationCode(using: fixture.environment))

        fixture.environment.settings.isGuestMode = false
        fixture.environment.session.signOut()
        await family.refresh(using: fixture.environment)
        #expect(!family.canEnterInvitationCode(using: fixture.environment))
        #expect(fixture.paths.isEmpty)
    }

    // MARK: - 홈의 가족 연결 안내

    @Test
    func guideExplainsInvitingWhenThereIsNoMemberAndNoInvitation() {
        #expect(guide([]) == .invite)
        #expect(guide(["me"]) == .invite)
        #expect(FamilyConnectGuide.invite.title == "가족과 연결해 보세요")
        #expect(FamilyConnectGuide.invite.lines == [
            "1. 「가족 초대하기」를 눌러 초대 코드를 만들어요.",
            "2. 코드를 가족에게 보내요. 가족은 콜록 앱 설정의 「초대 코드 입력」에 코드를 넣어요.",
            "3. 연결되면 여기서 바로 전화할 수 있어요."
        ])
        #expect(FamilyConnectGuide.invite.primaryActionTitle == "가족 초대하기")
        #expect(FamilyConnectGuide.codeEntryTitle == "초대 코드 입력")
    }

    @Test
    func guideWaitsWhileASentInvitationIsPending() {
        #expect(guide(["me", nil]) == .waiting)
        #expect(guide([nil]) == .waiting)
        #expect(FamilyConnectGuide.waiting.title == "초대 수락을 기다리고 있어요")
        #expect(FamilyConnectGuide.waiting.lines == ["가족이 콜록 앱 설정의 「초대 코드 입력」에 받은 코드를 넣으면 연결돼요."])
        // 누르면 초대 코드가 아니라 구성원 목록이 열린다
        #expect(FamilyConnectGuide.waiting.primaryActionTitle == "보낸 초대 보기")
    }

    @Test
    func guideAsksForANewCodeWhenEverySentInvitationHasExpired() {
        #expect(guide(["me", nil], hasUnexpiredInvitation: false) == .expired)
        #expect(guide([nil, nil], hasUnexpiredInvitation: false) == .expired)
        // 보낸 초대가 없으면 만료 여부와 상관없이 초대 안내
        #expect(guide(["me"], hasUnexpiredInvitation: false) == .invite)
        #expect(FamilyConnectGuide.expired.title == "보낸 초대가 만료됐어요")
        #expect(FamilyConnectGuide.expired.lines == ["「보낸 초대 보기」에서 새 초대 코드를 만들어 다시 보내주세요."])
        #expect(FamilyConnectGuide.expired.primaryActionTitle == "보낸 초대 보기")
    }

    @Test
    func familyStoreTellsExpiredInvitationsFromUsableOnes() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        var invitations: [String] = [invitation(expired: true), invitation(expired: true)]
        fixture.respond = { _ in (200, pendingMembers(invitations)) }

        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .expired)
        #expect(family.canEnterInvitationCode(using: fixture.environment))

        invitations = [invitation(expired: true), invitation(expired: false)]
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .waiting)

        // 서버가 만료로 알려 준 초대는 시각이 남아 있어도 만료다
        invitations = [invitation(expired: false, status: "EXPIRED")]
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .expired)

        invitations = []
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .invite)
    }

    @Test
    func guideHidesOnceSomeoneIsConnectedOrBeforeMembersAreKnownOrForGuests() {
        #expect(guide(["me", "parent"]) == nil)
        #expect(guide(["me", "parent", nil]) == nil)
        #expect(guide(nil) == nil)
        #expect(guide([], isGuest: true) == nil)
        #expect(guide(["me", nil], isGuest: true) == nil)
    }

    @Test
    func homeGuideFollowsTheLoadedFamily() async throws {
        let fixture = try TestEnvironment(role: "CHILD")
        defer { fixture.cleanUp() }
        let family = fixture.environment.family
        var userIds: [String?] = ["me"]
        fixture.respond = { request in
            if request.url?.path.hasSuffix("/members") == true { return (200, members(userIds)) }
            return (200, #"{"source":"fixture","questions":[]}"#)
        }
        #expect(family.connectGuide(using: fixture.environment) == nil)

        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .invite)

        userIds = ["me", nil]
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == .waiting)

        userIds = ["me", "parent"]
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == nil)

        userIds = ["me"]
        await family.refresh(using: fixture.environment)
        fixture.environment.settings.isGuestMode = true
        await family.refresh(using: fixture.environment)
        #expect(family.connectGuide(using: fixture.environment) == nil)
    }

    private func guide(
        _ memberUserIds: [String?]?, isGuest: Bool = false, hasUnexpiredInvitation: Bool = true
    ) -> FamilyConnectGuide? {
        .resolve(
            isGuest: isGuest, memberUserIds: memberUserIds, userId: "me",
            hasUnexpiredInvitation: hasUnexpiredInvitation
        )
    }

    private func invitation(expired: Bool, status: String = "PENDING") -> String {
        """
        {"invitationId":"invitation","code":"123456","shareText":"초대","status":"\(status)",
        "expiresAt":"\(expired ? "2020-01-01T00:00:00Z" : "2999-01-01T00:00:00Z")"}
        """
    }

    /// 나와, 아직 수락되지 않은 초대 줄들.
    private func pendingMembers(_ invitations: [String]) -> String {
        let rows = invitations.enumerated().map { index, invitation in
            """
            {"memberId":"invited-\(index)","userId":null,"name":"invited-\(index)","relation":"MOTHER",
            "status":"INVITED","invitation":\(invitation)}
            """
        } + [#"{"memberId":"me","userId":"me","name":"Me","relation":"","status":"ACTIVE"}"#]
        return "{\"members\":[\(rows.joined(separator: ","))]}"
    }

    /// 구성원 목록 응답. nil 은 아직 수락하지 않은 초대.
    private func members(_ userIds: [String?]) -> String {
        let rows = userIds.enumerated().map { index, userId in
            """
            {"memberId":"member-\(index)","userId":\(userId.map { "\"\($0)\"" } ?? "null"),
            "name":"member-\(index)","relation":"","status":"\(userId == nil ? "INVITED" : "ACTIVE")","role":"CHILD"}
            """
        }
        return "{\"members\":[\(rows.joined(separator: ","))]}"
    }
}
