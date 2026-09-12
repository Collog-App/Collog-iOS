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

    private(set) var contacts: [FamilyContact] = []
    private(set) var questions: [PreviewQuestion] = []
    private(set) var generatedQuestions: [String: [PreviewQuestion]] = [:]
    private(set) var selectedContactId: String?
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
        defaults.removeObject(forKey: Key.generatedQuestions)
    }

    func questions(for contact: FamilyContact?) -> [PreviewQuestion] {
        let source = contact.flatMap { generatedQuestions[$0.id] } ?? questions
        return source.reduce(into: [PreviewQuestion]()) { result, question in
            guard !result.contains(where: { $0.text == question.text }) else { return }
            result.append(question)
        }
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
        if environment.settings.isGuestMode {
            contacts = FamilyContact.samples
            questions = PreviewQuestion.samples
            selectedContactId = selectedContact?.id
            return
        }
        guard let familyId = environment.session.familyId else {
            reset()
            return
        }
        let userId = environment.session.user?.id
        do {
            let previousRelation = selectedContact?.relation
            let members = try await environment.api.members(familyId: familyId).filter(\.isCallable)
            guard environment.session.user?.id == userId else { return }
            contacts = members.map { FamilyContact(member: $0, lastCallText: $0.relationTitle) }
            selectedContactId = contacts.first { $0.relation == previousRelation }?.id ?? contacts.first?.id
            loadError = nil
        } catch {
            guard environment.session.user?.id == userId else { return }
            loadError = error.localizedDescription
        }

        let parentId = if let userId = selectedContact?.userId {
            userId
        } else {
            await environment.subjectParentId()
        }
        guard let parentId else { return }
        do {
            let remote = try await environment.api.dailyQuestions(parentId: parentId)
            guard environment.session.user?.id == userId else { return }
            questions = remote.map { PreviewQuestion(text: $0.text) }
            if let selectedContactId { generatedQuestions[selectedContactId] = questions }
        } catch {
            guard environment.session.user?.id == userId else { return }
            questions = []
            if let selectedContactId { generatedQuestions.removeValue(forKey: selectedContactId) }
            loadError = error.localizedDescription
        }
    }

    func reset() {
        contacts = []
        questions = []
        generatedQuestions = [:]
        selectedContactId = contacts.first?.id
        loadError = nil
        defaults.removeObject(forKey: Key.generatedQuestions)
    }
}
