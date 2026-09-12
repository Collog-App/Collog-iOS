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
    @State private var questionError: String?
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
                    if let summary = viewModel.healthSummary {
                        HealthStatusCardView(summary: summary, isLoaded: viewModel.isLoaded) {
                            navigation.manager(for: .home).push(Route.familyHealthOverview)
                        }
                        .matchedTransitionSource(id: Route.familyHealthOverview, in: detailTransition)
                        .padding(.bottom, Spacing.x5)
                    } else {
                        Text(viewModel.loadError ?? environment.family.loadError ?? "아직 분석된 통화 기록이 없어요")
                            .body_02_medium(.gray700)
                            .cardSurface()
                            .padding(.bottom, Spacing.x5)
                    }

                    QuestionListView(
                        questions: selectedQuestions,
                        isGenerating: isGeneratingQuestions,
                        onTap: generateQuestions
                    )
                        .padding(.bottom, Spacing.x4)

                    if let questionError {
                        Text(questionError)
                            .caption_01_medium(.red500)
                            .padding(.bottom, Spacing.x4)
                    }
                    if let feedback = viewModel.healthFeedback { feedbackRow(feedback) }
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
                    if let summary = viewModel.healthSummary {
                        FamilyHealthOverviewView(summary: summary)
                            .navigationTransition(
                                .zoom(sourceID: Route.familyHealthOverview, in: detailTransition)
                            )
                    }
                case .healthFeedbackDetail:
                    if let feedback = viewModel.healthFeedback {
                        HealthFeedbackDetailView(feedback: feedback)
                            .navigationTransition(
                                .zoom(sourceID: Route.healthFeedbackDetail, in: detailTransition)
                            )
                    }
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
        }
        .buttonStyle(.plain)
    }

    private func feedbackRow(_ feedback: HealthFeedback) -> some View {
        Button {
            navigation.manager(for: .home).push(Route.healthFeedbackDetail)
        } label: {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(feedback.title)
                        .caption_01_medium(.gray800)

                    Text(feedback.headline)
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
        questionGenerationId = nil
        isGeneratingQuestions = false
        questionError = nil
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
        questionError = nil
        let existing = selectedQuestions.map(\.text)
        let userId = environment.session.user?.id

        if !environment.settings.isGuestMode {
            Task {
                do {
                    let parentId = environment.session.user?.role == "PARENT" ? userId : selectedContact.userId
                    guard let parentId else { throw APIError.unauthenticated }
                    let questions = try await environment.api.dailyQuestions(parentId: parentId)
                    guard environment.session.user?.id == userId else { return }
                    completeQuestionGeneration(
                        questions.map(\.text),
                        contact: selectedContact,
                        generationId: generationId
                    )
                } catch {
                    guard questionGenerationId == generationId, environment.session.user?.id == userId else { return }
                    questionError = error.localizedDescription
                    questionGenerationId = nil
                    isGeneratingQuestions = false
                }
            }
            return
        }

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
        guard questionGenerationId == generationId, environment.family.selectedContactId == contact.id else { return }
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
