//
//  HomeView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var navigationManager = NavigationManager()

    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            VStack(spacing: 0) {
                HomeTopBarView(onNotificationTap: { navigationManager.push(Route.notifications) })

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.x6) {
                        if let primaryContact = viewModel.primaryContact {
                            NextCallCardView(
                                contact: primaryContact,
                                questions: viewModel.questions,
                                onQuestionsTap: { navigationManager.push(Route.questionPreview) }
                            )
                        }

                        otherFamilySection

                        healthSection
                    }
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x2)
                    .padding(.bottom, Spacing.x8)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.gray50)
            .environment(\.navigationManager, navigationManager)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .familyHealthOverview: Text("가족 건강 전체 보기")
                case .healthFeedbackDetail: Text("건강 피드백")
                case .questionPreview: Text("오늘의 질문")
                case .notifications: Text("알림")
                }
            }
        }
    }

    @ViewBuilder
    private var otherFamilySection: some View {
        if !viewModel.otherContacts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                SectionHeaderView(title: "다른 가족")

                ForEach(viewModel.otherContacts) { contact in
                    FamilyContactRowView(contact: contact)
                }
            }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            SectionHeaderView(title: "건강 변화")

            FamilyHealthCardView(
                summary: viewModel.healthSummary,
                onSeeAllTap: { navigationManager.push(Route.familyHealthOverview) }
            )

            HealthFeedbackCardView(
                feedback: viewModel.healthFeedback,
                onMoreTap: { navigationManager.push(Route.healthFeedbackDetail) }
            )
        }
    }
}

#Preview {
    HomeView()
}
