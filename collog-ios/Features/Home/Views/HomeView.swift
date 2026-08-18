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
                        callSection

                        healthSection

                        questionSection
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
                case .notifications: Text("알림")
                }
            }
        }
    }

    private var callSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            SectionHeaderView(title: "가족 전화하기")

            ForEach(viewModel.contacts) { contact in
                FamilyContactRowView(contact: contact)
            }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            SectionHeaderView(title: "우리 가족 건강")

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

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            UnderlineTabsView(titles: viewModel.sectionTitles, selection: $viewModel.selectedSectionIndex)

            if viewModel.selectedSectionIndex == 0 {
                QuestionPreviewSectionView(questions: viewModel.questions)
            } else {
                Text("전화 로그는 준비 중이에요")
                    .body_02_medium(.gray700)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    HomeView()
}
