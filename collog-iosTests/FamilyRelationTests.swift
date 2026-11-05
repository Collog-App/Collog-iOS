//
//  FamilyRelationTests.swift
//  collog-ios
//

import Testing
@testable import collog_ios

@MainActor
struct FamilyRelationTests {
    @Test
    func invitationOptionsMatchServerRelationsAndAndroidLabels() {
        #expect(FamilyRelation.invitationOptions == [
            "MOTHER", "FATHER", "SPOUSE", "CHILD", "SIBLING", "GRANDPARENT", "OTHER"
        ])
        #expect(FamilyRelation.invitationOptions.map(FamilyRelation.title) == [
            "어머니", "아버지", "배우자", "자녀", "형제자매", "조부모", "가족"
        ])
    }

    @Test
    func creatorWithoutRelationShowsNameAndLegacyParentStaysReadable() {
        #expect(FamilyRelation.title("") == nil)
        #expect(FamilyRelation.title("PARENT") == "부모")
        let creator = FamilyMember(
            memberId: "creator", userId: "owner", name: "Emul1", relation: "", status: "ACTIVE",
            role: "CHILD", invitation: nil
        )
        #expect(creator.relationTitle == "Emul1")
    }
}
