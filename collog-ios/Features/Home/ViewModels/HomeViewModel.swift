//
//  HomeViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class HomeViewModel {
    private(set) var contacts: [FamilyContact] = FamilyContact.samples
    private(set) var healthSummary: FamilyHealthSummary = .sample
    private(set) var healthFeedback: HealthFeedback = .sample
    private(set) var questions: [PreviewQuestion] = PreviewQuestion.samples
    private(set) var loadError: String?

    var primaryContact: FamilyContact? { contacts.first }

    var otherContacts: [FamilyContact] { Array(contacts.dropFirst()) }

    func refresh(using environment: AppEnvironment) async {
        guard let familyId = environment.session.familyId else { return }
        do {
            let members = try await environment.api.members(familyId: familyId)
            let callable = members.filter(\.isCallable)
            if !callable.isEmpty {
                contacts = callable.map { FamilyContact(member: $0, lastCallText: "") }
            }
            if let parentId = callable.first?.userId {
                let remote = try await environment.api.dailyQuestions(parentId: parentId)
                if !remote.isEmpty {
                    questions = remote.map { PreviewQuestion(text: $0.text) }
                }
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
