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
    /// 지금 가족 구성원의 userId(아직 수락하지 않은 초대는 nil). 가족이 없으면 빈 목록이다.
    /// 구성원 목록을 읽기 전과 둘러보기에서는 nil 이라 「초대 코드 입력」을 띄우지 않는다.
    private(set) var memberUserIds: [String?]?

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

    /// 설정·계정 정보가 함께 쓰는 「초대 코드 입력」 조건(`FamilyInvitationAccess.canEnterCode`).
    func canEnterInvitationCode(using environment: AppEnvironment) -> Bool {
        guard let memberUserIds else { return false }
        return FamilyInvitationAccess.canEnterCode(
            isGuest: environment.settings.isGuestMode,
            memberUserIds: memberUserIds,
            userId: environment.session.user?.id
        )
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
            memberUserIds = nil
            return
        }
        guard let familyId = environment.session.familyId else {
            reset()
            if environment.session.isAuthenticated { memberUserIds = [] }
            return
        }
        let userId = environment.session.user?.id
        do {
            // 역할 구분 없이 나를 뺀 연결된 가족 모두가 연락처다
            let allMembers = try await environment.api.members(familyId: familyId)
            let members = allMembers.filter { $0.isCallable && $0.userId != userId }
            guard environment.session.user?.id == userId, refreshGeneration == generation else { return }
            memberUserIds = allMembers.map(\.userId)
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
        // 오늘의 질문은 고른 가족(통화 상대)의 프로필로 만든다
        guard let parentId = selectedContact?.userId else { return }
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
        memberUserIds = nil
        defaults.removeObject(forKey: Key.generatedQuestions)
    }
}
