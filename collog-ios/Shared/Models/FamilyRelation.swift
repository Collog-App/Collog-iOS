//
//  FamilyRelation.swift
//  collog-ios
//

import Foundation

enum FamilyRelation {
    /// 서버 `InvitationCreate.relation` 이 받는 값, 초대할 때 고르는 순서.
    static let invitationOptions = ["MOTHER", "FATHER", "SPOUSE", "CHILD", "SIBLING", "GRANDPARENT", "OTHER"]

    /// 관계 이름. 가족을 만든 사람처럼 비어 있으면 nil. 예전 서버의 PARENT는 「부모」.
    static func title(_ relation: String) -> String? {
        switch relation {
        case "": nil
        case "MOTHER": "어머니"
        case "FATHER": "아버지"
        case "SPOUSE": "배우자"
        case "CHILD": "자녀"
        case "SIBLING": "형제자매"
        case "GRANDPARENT": "조부모"
        case "PARENT": "부모"
        default: "가족"
        }
    }
}
