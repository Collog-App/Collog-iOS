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
    @ObservationIgnored private var refreshGeneration = UUID()

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
        let source = contact.flatMap { generatedQuestions[$0.id] } ?? []
        return source.reduce(into: [PreviewQuestion]()) { result, question in
            guard !result.contains(where: { $0.text == question.text }) else { return }
            result.append(question)
        }
    }

    func selectContact(_ contact: FamilyContact) {
        selectedContactId = contact.id
        refreshGeneration = UUID()
    }

    func saveQuestions(_ texts: [String], for contact: FamilyContact) {
        generatedQuestions[contact.id] = texts.map(PreviewQuestion.init(text:))
        let stored = generatedQuestions.mapValues { $0.map(\.text) }
        defaults.set(stored, forKey: Key.generatedQuestions)
    }

    func refresh(using environment: AppEnvironment) async {
        let generation = UUID()
        refreshGeneration = generation
        if environment.settings.isGuestMode {
            contacts = FamilyContact.samples
            questions = PreviewQuestion.samples
            for contact in contacts where generatedQuestions[contact.id] == nil {
                generatedQuestions[contact.id] = questions
            }
            selectedContactId = selectedContact?.id
            return
        }
        guard let familyId = environment.session.familyId else {
            reset()
            return
        }
        let userId = environment.session.user?.id
        do {
            let members = try await environment.api.members(familyId: familyId).filter {
                $0.isCallable && $0.userId != userId && $0.role != environment.session.user?.role
            }
            guard environment.session.user?.id == userId, refreshGeneration == generation else { return }
            contacts = members.map { FamilyContact(member: $0, lastCallText: $0.relationTitle) }
            if !contacts.contains(where: { $0.id == selectedContactId }) {
                selectedContactId = contacts.first?.id
            }
            loadError = nil
        } catch {
            guard environment.session.user?.id == userId, refreshGeneration == generation else { return }
            loadError = error.localizedDescription
            return
        }

        let contactId = selectedContactId
        let parentId = if environment.session.user?.role == "PARENT" {
            userId
        } else if let userId = selectedContact?.userId {
            userId
        } else {
            await environment.subjectParentId()
        }
        guard let parentId else { return }
        do {
            let remote = try await environment.api.dailyQuestions(parentId: parentId)
            guard environment.session.user?.id == userId, refreshGeneration == generation,
                  selectedContactId == contactId else { return }
            questions = remote.map { PreviewQuestion(text: $0.text) }
            if let contactId { generatedQuestions[contactId] = questions }
        } catch {
            guard environment.session.user?.id == userId, refreshGeneration == generation,
                  selectedContactId == contactId else { return }
            questions = []
            if let contactId { generatedQuestions.removeValue(forKey: contactId) }
            loadError = error.localizedDescription
        }
    }

    func reset() {
        refreshGeneration = UUID()
        contacts = []
        questions = []
        generatedQuestions = [:]
        selectedContactId = contacts.first?.id
        loadError = nil
        defaults.removeObject(forKey: Key.generatedQuestions)
    }
}
