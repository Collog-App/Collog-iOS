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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CallCenter.self) private var callCenter

    @State private var viewModel = HomeViewModel()
    @State private var todoModel = TodoListModel()
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
                    } else if !viewModel.isLoaded {
                        ProgressView("통화 기록을 불러오고 있어요")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.x8)
                    } else if let error = viewModel.loadError ?? viewModel.recentCallsError
                        ?? environment.family.loadError {
                        EmptyStateView(
                            symbol: "exclamationmark.circle", title: "데이터를 불러오지 못했어요.",
                            message: error, actionTitle: "다시 시도"
                        ) { Task { await refresh() } }
                            .cardSurface()
                            .padding(.bottom, Spacing.x5)
                    } else {
                        AnalysisEmptyStateView(
                            contact: selectedContact, calls: viewModel.recentCalls, onRefresh: refresh
                        )
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

                    TodoListCardView(model: todoModel)
                        .padding(.bottom, Spacing.x4)

                    if let feedback = viewModel.healthFeedback { feedbackRow(feedback) }

                    // 건강 앱 연결 안내(피그마 없음): 아직 연결 안 했고 쓸 수 있는 기기일 때, 닫으면 다시 안 띄운다
                    if environment.health.shouldShowHint(using: environment) {
                        HealthLinkHintCardView(
                            onConnect: { environment.health.present() },
                            onClose: {
                                Haptics.blur()
                                environment.health.dismissHint(using: environment)
                            }
                        )
                        .padding(.top, viewModel.healthFeedback == nil ? 0 : Spacing.x4)
                    }
                }
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: environment.family.selectedContactId)
                .padding(.horizontal, Spacing.x5)
                .padding(.bottom, Spacing.x8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await initialRefresh() }
            // 앱으로 돌아왔을 때·통화가 끝났을 때: 마지막 통화 시각과 분석 상태를 화면 깜빡임 없이 다시 읽는다.
            .onChange(of: scenePhase) {
                guard scenePhase == .active, viewModel.isLoaded else { return }
                Task { await viewModel.refreshCalls(using: environment, contact: selectedContact) }
            }
            .onChange(of: callCenter.activeCall == nil) { _, isIdle in
                guard isIdle, viewModel.isLoaded else { return }
                Task { await viewModel.refreshCalls(using: environment, contact: selectedContact) }
            }
            // 분석 완료 알림을 받으면(누르지 않고 배너로만 봐도) 건강 요약을 다시 읽는다
            .onChange(of: environment.reportDataRevision) {
                Task { await refresh() }
            }
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

    /// 피그마 「홈 · 메인」 헤더: 아바타 53 · 이름 Bold 22 + 관계 태그 + 화살표 · 마지막 통화 14.
    @ViewBuilder
    private var largeTitle: some View {
        HStack(alignment: .top, spacing: 10) {
            if let contact = selectedContact {
                ViewerAvatar(contact: contact, size: 53, fullColor: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                if contacts.count > 1 {
                    Menu {
                        ForEach(contacts) { contact in
                            Button(contact.name) { select(contact) }
                        }
                    } label: { nameRow(showsChevron: true) }
                } else {
                    nameRow(showsChevron: false)
                }

                Text(viewModel.lastCallText)
                    .pretendard(.regular, 14, Color(hex: 0x8A9099))
            }
        }
    }

    private func nameRow(showsChevron: Bool) -> some View {
        HStack(spacing: 7) {
            HStack(spacing: 8) {
                Text(selectedContact?.name ?? "가족")
                    .pretendard(.bold, 22, Color(hex: 0x2D3139))
                if let contact = selectedContact {
                    Text(ViewerProfileHeader.relationText(for: contact))
                        .pretendard(.semiBold, 13.5, Color(hex: 0x159A5E))
                        .padding(.horizontal, 10.35)
                        .padding(.vertical, 4.14)
                        .background(Color(hex: 0xE6F7EE), in: Capsule())
                }
            }
            if showsChevron {
                Icon(name: "chevron.down", size: 18, weight: .semibold, color: Color(hex: 0x4A5058))
            }
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
                    guard let parentId = selectedContact.userId else { throw APIError.unauthenticated }
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
        // 오늘 할 일은 가족 선택과 무관하게 본인 목록이라 따로 불러온다
        Task { await todoModel.load(using: environment) }
        await environment.family.refresh(using: environment)
        await viewModel.refresh(
            using: environment,
            contact: selectedContact
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
