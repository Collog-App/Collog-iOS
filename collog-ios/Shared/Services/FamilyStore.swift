//
//  FamilyStore.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class FamilyStore {
    private enum Key {
        static let generatedQuestions = "family.generatedQuestions"
    }

    private(set) var contacts: [FamilyContact] = FamilyContact.samples
    private(set) var questions: [PreviewQuestion] = PreviewQuestion.samples
    private(set) var generatedQuestions: [String: [PreviewQuestion]] = [:]
    private(set) var selectedContactId = FamilyContact.samples.first?.id
    private(set) var loadError: String?

    @ObservationIgnored private let defaults: UserDefaults

    var callableContacts: [FamilyContact] { contacts.filter(\.isCallable) }

    var selectedContact: FamilyContact? {
        contacts.first { $0.id == selectedContactId } ?? contacts.first
    }

    var selectedQuestionTexts: [String] {
        questions(for: selectedContact).map(\.text)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Key.generatedQuestions) as? [String: [String]] ?? [:]
        generatedQuestions = stored.mapValues { $0.map(PreviewQuestion.init(text:)) }
    }

    func questions(for contact: FamilyContact?) -> [PreviewQuestion] {
        guard let contact else { return questions }
        return generatedQuestions[contact.id] ?? questions
    }

    func selectContact(_ contact: FamilyContact) {
        selectedContactId = contact.id
    }

    func saveQuestions(_ texts: [String], for contact: FamilyContact) {
        generatedQuestions[contact.id] = texts.map(PreviewQuestion.init(text:))
        let stored = generatedQuestions.mapValues { $0.map(\.text) }
        defaults.set(stored, forKey: Key.generatedQuestions)
    }

    func refresh(using environment: AppEnvironment) async {
        guard let familyId = environment.session.familyId else { return }
        do {
            let previousRelation = selectedContact?.relation
            let members = try await environment.api.members(familyId: familyId).filter(\.isCallable)
            if !members.isEmpty {
                contacts = members.map { FamilyContact(member: $0, lastCallText: $0.relationTitle) }
                selectedContactId = contacts.first { $0.relation == previousRelation }?.id ?? contacts.first?.id
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
