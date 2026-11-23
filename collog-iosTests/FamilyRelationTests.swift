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

    @Test
    func invitationNeedsNameAndAChosenRelation() {
        // 관계를 미리 골라 두지 않는다: 고르기 전에는 만들 수 없다
        #expect(!FamilyInvitationForm.canCreate(name: "엄마", relation: nil, isSubmitting: false))
        #expect(FamilyInvitationForm.relationPlaceholder == "관계를 선택해주세요")
        for relation in FamilyRelation.invitationOptions {
            #expect(FamilyInvitationForm.canCreate(name: "엄마", relation: relation, isSubmitting: false))
        }
        #expect(!FamilyInvitationForm.canCreate(name: "", relation: "FATHER", isSubmitting: false))
        #expect(!FamilyInvitationForm.canCreate(name: "엄마", relation: "FATHER", isSubmitting: true))
    }
}
