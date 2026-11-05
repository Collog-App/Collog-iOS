//
//  FamilyInvitationAccessTests.swift
//  collog-ios
//

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
}
