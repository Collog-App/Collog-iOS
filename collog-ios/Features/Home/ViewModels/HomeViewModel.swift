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

    var primaryContact: FamilyContact? { contacts.first }

    var otherContacts: [FamilyContact] { Array(contacts.dropFirst()) }
}
