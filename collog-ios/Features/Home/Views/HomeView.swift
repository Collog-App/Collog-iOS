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
    @Environment(TabManager.self) private var tabManager

    @State private var viewModel = HomeViewModel()
    @State private var selectedContactId: String?
    @Namespace private var detailTransition

    private var contacts: [FamilyContact] { environment.family.contacts }

    private var selectedContact: FamilyContact? {
        contacts.first { $0.id == selectedContactId } ?? contacts.first
    }

    var body: some View {
        @Bindable var navigator = navigation.manager(for: .home)

        return NavigationStack(path: $navigator.path) {
            CollapsingHeaderScrollView(
                title: selectedContact?.name ?? "가족",
                onRefresh: refresh,
                scrollReset: tabManager.reselectionCount
            ) {
                largeTitle
            } trailing: {
                trailingIcons
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    HealthStatusCardView(summary: viewModel.healthSummary, isLoaded: viewModel.isLoaded) {
                        navigation.manager(for: .home).push(Route.familyHealthOverview)
                    }
                    .matchedTransitionSource(id: Route.familyHealthOverview, in: detailTransition)
                    .padding(.bottom, Spacing.x5)

                    QuestionListView(questions: environment.family.questions) {
                        navigation.manager(for: .home).push(Route.questionPreview)
                    }
                        .matchedTransitionSource(id: Route.questionPreview, in: detailTransition)
                        .padding(.bottom, Spacing.x4)

                    feedbackRow
                }
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: selectedContactId)
                .padding(.horizontal, Spacing.x5)
                .padding(.bottom, Spacing.x8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await initialRefresh() }
            .environment(\.navigationManager, navigator)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .familyHealthOverview:
                    FamilyHealthOverviewView(summary: viewModel.healthSummary)
                        .navigationTransition(
                            .zoom(sourceID: Route.familyHealthOverview, in: detailTransition)
                        )
                case .healthFeedbackDetail:
                    HealthFeedbackDetailView(
                        feedback: viewModel.healthFeedback,
                        summary: viewModel.healthSummary
                    )
                    .navigationTransition(
                        .zoom(sourceID: Route.healthFeedbackDetail, in: detailTransition)
                    )
                case .questionPreview:
                    QuestionPreviewView(
                        questions: environment.family.questions,
                        memberName: selectedContact?.name ?? "가족"
                    )
                        .navigationTransition(
                            .zoom(sourceID: Route.questionPreview, in: detailTransition)
                        )
                case .notifications:
                    HomeNotificationsView()
                case .homeMenu:
                    HomeMenuView(contact: selectedContact)
                }
            }
        }
    }

    @ViewBuilder
    private var largeTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            if contacts.count > 1 {
                Menu {
                    ForEach(contacts) { contact in
                        Button(contact.name) { select(contact) }
                    }
                } label: {
                    HStack(spacing: Spacing.x1) {
                        Text(selectedContact?.name ?? "가족")
                            .headline_02(.gray900)
                        Icon(name: "chevron.down", size: 18, weight: .semibold, color: .gray700)
                    }
                }
            } else {
                Text(selectedContact?.name ?? "가족")
                    .headline_02(.gray900)
            }

            Text(viewModel.lastCallText)
                .body_03_medium(.gray700)
        }
    }

    private var trailingIcons: some View {
        HStack(spacing: 0) {
            Button {
                navigation.manager(for: .home).push(Route.notifications)
            } label: {
                Icon(name: "bell", color: .gray900)
                    .frame(width: 40, height: 40)
                    .overlay(alignment: .topTrailing) {
                        NotificationDot().offset(x: -4, y: 4)
                    }
            }
            .buttonStyle(.plain)

            Button {
                navigation.manager(for: .home).push(Route.homeMenu)
            } label: {
                Icon(name: "line.3.horizontal", color: .gray900)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackRow: some View {
        Button {
            navigation.manager(for: .home).push(Route.healthFeedbackDetail)
        } label: {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(viewModel.healthFeedback.title)
                        .caption_01_medium(.gray800)

                    Text(viewModel.healthFeedback.headline)
                        .body_02_medium(.gray900)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.x2)

                Icon(name: "chevron.right", size: 14, color: .gray500)
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: Route.healthFeedbackDetail, in: detailTransition)
    }

    private func select(_ contact: FamilyContact) {
        guard selectedContactId != contact.id else { return }
        Haptics.focus()
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedContactId = contact.id
        }
        Task { await refresh() }
    }

    private func refresh() async {
        await environment.family.refresh(using: environment)
        await viewModel.refresh(using: environment, contact: selectedContact)
    }

    private func initialRefresh() async {
        await environment.family.refresh(using: environment)
        await viewModel.refresh(
            using: environment,
            contact: selectedContact,
            showsLoading: true
        )
    }
}

#Preview {
    let environment = AppEnvironment()

    HomeView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
        .environment(NavigationStore())
}
