//
//  FamilyStore.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class FamilyStore {
    private(set) var contacts: [FamilyContact] = FamilyContact.samples
    private(set) var questions: [PreviewQuestion] = PreviewQuestion.samples
    private(set) var loadError: String?

    var callableContacts: [FamilyContact] { contacts.filter(\.isCallable) }

    func refresh(using environment: AppEnvironment) async {
        guard let familyId = environment.session.familyId else { return }
        do {
            let members = try await environment.api.members(familyId: familyId).filter(\.isCallable)
            if !members.isEmpty {
                contacts = members.map { FamilyContact(member: $0, lastCallText: "") }
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        guard let parentId = await environment.subjectParentId() else { return }
        if let remote = try? await environment.api.dailyQuestions(parentId: parentId), !remote.isEmpty {
            questions = remote.map { PreviewQuestion(text: $0.text) }
        }
    }
}
