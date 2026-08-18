//
//  FamilyContact.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct FamilyContact: Identifiable, Hashable {
    let id: String
    let userId: String?
    let name: String
    let relation: String
    let lastCallText: String

    var isCallable: Bool { userId != nil }
}

extension FamilyContact {
    init(member: FamilyMember, lastCallText: String) {
        self.init(
            id: member.memberId,
            userId: member.userId,
            name: member.name,
            relation: member.relation,
            lastCallText: lastCallText
        )
    }

    static let samples: [FamilyContact] = [
        FamilyContact(id: "sample-mother", userId: nil, name: "어머니", relation: "MOTHER", lastCallText: "3일 전 통화"),
        FamilyContact(id: "sample-father", userId: nil, name: "아버지", relation: "FATHER", lastCallText: "그저께 통화")
    ]
}
