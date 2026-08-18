//
//  HomeViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class HomeViewModel {
    var selectedSectionIndex: Int = 0

    private(set) var contacts: [FamilyContact] = FamilyContact.samples
    private(set) var healthSummary: FamilyHealthSummary = .sample
    private(set) var healthFeedback: HealthFeedback = .sample
    private(set) var questions: [PreviewQuestion] = PreviewQuestion.samples

    let sectionTitles = ["질문 미리보기", "전화 로그"]
}
