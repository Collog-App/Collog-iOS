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
    let relation: String
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
        FamilyContact(name: "어머니", relation: "어머니", lastCallText: "3일 전 통화", direction: .outgoing),
        FamilyContact(name: "아버지", relation: "아버지", lastCallText: "그저께 통화", direction: .incoming)
    ]
}
