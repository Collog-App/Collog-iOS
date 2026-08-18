//
//  FamilyContact.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

enum CallDirection {
    case incoming
    case outgoing
}

struct FamilyContact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let line: String
    let lastCallText: String
    let direction: CallDirection

    static func == (lhs: FamilyContact, rhs: FamilyContact) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FamilyContact {
    static let samples: [FamilyContact] = [
        FamilyContact(name: "아버지", line: "휴대전화", lastCallText: "그저께", direction: .incoming),
        FamilyContact(name: "어머니", line: "휴대전화", lastCallText: "어제", direction: .outgoing)
    ]
}
