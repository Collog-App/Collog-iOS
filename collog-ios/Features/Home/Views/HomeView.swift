//
//  HomeView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    @Environment(NavigationStore.self) private var navigation

    @State private var viewModel = HomeViewModel()
    @State private var selectedContactId: String?

    private var contacts: [FamilyContact] { environment.family.contacts }

    private var selectedContact: FamilyContact? {
        contacts.first { $0.id == selectedContactId } ?? contacts.first
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: .home)

        return NavigationStack(path: $navigator.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x8) {
                    if let selectedContact {
                        HomeHeaderView(
                            contacts: contacts,
                            selected: selectedContact,
                            subtitle: viewModel.lastCallText,
                            onSelect: { select($0) },
                            onNotificationTap: { navigation.manager(for: .home).push(Route.notifications) }
                        )

                        VStack(alignment: .leading, spacing: Spacing.x8) {
                            HealthStatusCardView(summary: viewModel.healthSummary) {
                                navigation.manager(for: .home).push(Route.familyHealthOverview)
                            }

                            QuestionListView(questions: environment.family.questions)

                            feedbackRow
                        }
                        .padding(.horizontal, Spacing.x5)
                    }
                }
                .padding(.bottom, Spacing.x8)
            }
            .scrollIndicators(.hidden)
            .background(Color.gray50)
            .task { await refresh() }
            .environment(\.navigationManager, navigator)
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

    private var feedbackRow: some View {
        Button {
            navigation.manager(for: .home).push(Route.healthFeedbackDetail)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                DividerLine()

                HStack(spacing: Spacing.x2) {
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        Text(viewModel.healthFeedback.title)
                            .body_02_semibold(.gray900)

                        Text(viewModel.healthFeedback.headline)
                            .body_03_medium(.gray700)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.x2)

                    Icon(name: "chevron.right", size: 14, color: .gray500)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func select(_ contact: FamilyContact) {
        selectedContactId = contact.id
        Task { await refresh() }
    }

    private func refresh() async {
        await environment.family.refresh(using: environment)
        await viewModel.refresh(using: environment, contact: selectedContact)
    }
}

#Preview {
    let environment = AppEnvironment()

    HomeView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
}
