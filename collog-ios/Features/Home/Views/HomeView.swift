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
    @State private var isGeneratingQuestions = false
    @State private var questionGenerationId: UUID?
    @Namespace private var detailTransition

    private var contacts: [FamilyContact] { environment.family.contacts }

    private var selectedContact: FamilyContact? {
        environment.family.selectedContact
    }

    private var selectedQuestions: [PreviewQuestion] {
        environment.family.questions(for: selectedContact)
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
                notificationButton
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    HealthStatusCardView(summary: viewModel.healthSummary, isLoaded: viewModel.isLoaded) {
                        navigation.manager(for: .home).push(Route.familyHealthOverview)
                    }
                    .matchedTransitionSource(id: Route.familyHealthOverview, in: detailTransition)
                    .padding(.bottom, Spacing.x5)

                    QuestionListView(
                        questions: selectedQuestions,
                        isGenerating: isGeneratingQuestions,
                        onTap: generateQuestions
                    )
                        .padding(.bottom, Spacing.x4)

                    feedbackRow
                }
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: environment.family.selectedContactId)
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
                    HealthFeedbackDetailView(feedback: viewModel.healthFeedback)
                    .navigationTransition(
                        .zoom(sourceID: Route.healthFeedbackDetail, in: detailTransition)
                    )
                case .notifications:
                    HomeNotificationsView()
                        .interactivePopGestureEnabled()
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

    private var notificationButton: some View {
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
        guard environment.family.selectedContactId != contact.id else { return }
        Haptics.focus()
        withAnimation(.easeInOut(duration: 0.18)) {
            environment.family.selectContact(contact)
        }
        Task { await refresh() }
    }

    private func generateQuestions() {
        guard let selectedContact, !isGeneratingQuestions else { return }
        let generationId = UUID()
        questionGenerationId = generationId
        isGeneratingQuestions = true
        let existing = selectedQuestions.map(\.text)

        Task {
            let generated = await QuestionGenerator.generate(
                memberName: selectedContact.name,
                excluding: existing
            )
            completeQuestionGeneration(
                generated,
                contact: selectedContact,
                generationId: generationId
            )
        }

        Task {
            try? await Task.sleep(for: .seconds(6))
            let fallback = QuestionGenerator.fallback(excluding: existing)
            completeQuestionGeneration(
                fallback,
                contact: selectedContact,
                generationId: generationId
            )
        }
    }

    private func completeQuestionGeneration(
        _ questions: [String],
        contact: FamilyContact,
        generationId: UUID
    ) {
        guard questionGenerationId == generationId else { return }
        environment.family.saveQuestions(questions, for: contact)
        questionGenerationId = nil
        isGeneratingQuestions = false
        Haptics.commit()
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
