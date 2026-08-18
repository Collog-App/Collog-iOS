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
                    VStack(alignment: .leading, spacing: Spacing.x4) {
                        SectionHeaderView(title: "가족 전화하기")
                            .padding(.top, Spacing.x6)

                        VStack(spacing: Spacing.x4) {
                            ForEach(viewModel.contacts) { contact in
                                FamilyContactRowView(contact: contact)
                            }
                        }
                        .padding(.top, Spacing.x1)

                        FamilyHealthCardView(
                            summary: viewModel.healthSummary,
                            feedback: viewModel.healthFeedback,
                            onSeeAllTap: { navigationManager.push(Route.familyHealthOverview) },
                            onFeedbackMoreTap: { navigationManager.push(Route.healthFeedbackDetail) }
                        )

                        SegmentedTabsView(
                            titles: viewModel.sectionTitles,
                            selection: $viewModel.selectedSectionIndex
                        )

                        if viewModel.selectedSectionIndex == 0 {
                            QuestionPreviewSectionView(questions: viewModel.questions)
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.bottom, Spacing.x8)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.gray00)
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
}

#Preview {
    HomeView()
}
