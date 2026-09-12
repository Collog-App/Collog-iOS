//
//  RootView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI
import AuthenticationServices

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(CallCenter.self) private var callCenter
    @Environment(\.scenePhase) private var scenePhase

    @State private var tabManager = TabManager()
    @State private var navigation = NavigationStore()
    @State private var authFlow = AuthFlowViewModel()
    @State private var launcher = CallLauncherModel()

    @State private var simulatedContact: FamilyContact?
    @State private var simulatedPhase: CallPhase = .connecting
    @State private var simulationTask: Task<Void, Never>?

    private var isGuest: Bool { environment.settings.isGuestMode }

    var body: some View {
        sessionContent
            .alert("통화를 진행할 수 없어요", isPresented: Binding(
                get: { callCenter.callError != nil },
                set: { if !$0 { callCenter.callError = nil } }
            )) {
                if callCenter.needsMicrophoneSettings {
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("확인", role: .cancel) { callCenter.callError = nil }
            } message: {
                Text(callCenter.callError ?? "")
            }
            .environment(tabManager)
            .environment(navigation)
    }

    private var sessionContent: some View {
        ZStack {
            authContent(for: authFlow.step)
        }
        .animation(.easeInOut(duration: 0.2), value: authFlow.step)
        .task {
            await environment.session.checkAppleCredential(using: environment.settings.resolvedBaseURL)
            await authFlow.resolve(using: environment)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
        )) { _ in
            Task { await environment.session.checkAppleCredential(using: environment.settings.resolvedBaseURL) }
        }
        .onChange(of: environment.session.isAuthenticated) {
            if !environment.session.isAuthenticated {
                callCenter.endActiveCall()
                launcher.dismiss()
            }
            Task { await authFlow.resolve(using: environment) }
        }
        .onChange(of: environment.settings.isGuestMode) {
            environment.family.reset()
            Task { await authFlow.resolve(using: environment) }
        }
        .onChange(of: environment.settings.callNotificationsEnabled) {
            callCenter.registerDeviceIfPossible()
        }
        .onChange(of: environment.settings.reportNotificationsEnabled) {
            callCenter.updateNotificationAuthorization()
        }
        .onChange(of: environment.settings.questionVoiceEnabled) {
            callCenter.updateQuestionVoicePreference()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, environment.session.isAuthenticated {
                callCenter.updateNotificationAuthorization()
                Task { await environment.session.checkAppleCredential(using: environment.settings.resolvedBaseURL) }
            }
        }
        .onChange(of: environment.reportNotificationRevision) {
            navigation.popToRoot(.report)
            tabManager.selectedTab = .report
        }
        .fullScreenCover(isPresented: callPresentation) {
            callScreen
        }
    }

    @ViewBuilder
    private func authContent(for step: AuthFlowViewModel.Step) -> some View {
        switch step {
        case .launching:
            Color.gray50
                .ignoresSafeArea()
        case .onboarding:
            OnboardingView {
                environment.settings.onboardingCompleted = true
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .login:
            LoginView {
                callCenter.registerDeviceIfPossible()
                if environment.session.isAuthenticated { callCenter.updateNotificationAuthorization() }
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .consent:
            ConsentView {
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .invitation:
            InvitationAcceptView {
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .profile:
            HealthProfileSetupView {
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .ready:
            mainTabs
                .id(isGuest ? "guest" : environment.session.user?.id ?? "signed-out")
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
        }
    }

    private var mainTabs: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    tabContent
                        .id(tabManager.selectedTab)
                        .id(environment.reportNotificationRevision)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.18), value: tabManager.selectedTab)

                Color.clear
                    .frame(height: BottomNavBarView.barHeight)
            }

            if launcher.isPresented {
                CallLauncherOverlay(
                    model: launcher,
                    anchorInset: BottomNavBarView.anchorInset,
                    notice: launcherNotice,
                    onSelect: { index in
                        if let contact = launcher.select(index) { startCall(contact) }
                    },
                    onDismiss: { launcher.dismiss() }
                )
            }

            VStack(spacing: 0) {
                Spacer()
                BottomNavBarView(
                    selection: $tabManager.selectedTab,
                    launcher: launcher,
                    onLaunch: startCall,
                    onReselect: reselect
                )
            }
        }
        .background(Color.gray50)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: launcher.isPresented)
        .task {
            await environment.family.refresh(using: environment)
            syncLauncher()
        }
        .onChange(of: environment.family.contacts) { syncLauncher() }
        .onChange(of: environment.family.selectedQuestionTexts) { syncLauncher() }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tabManager.selectedTab {
        case .home:
            HomeView()
        case .report:
            ReportTimelineView(initialTabIndex: 0)
        case .timeline:
            ReportTimelineView(initialTabIndex: 1)
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private var callScreen: some View {
        if let call = callCenter.activeCall {
            CallView(
                peerName: call.peerName,
                phase: call.phase,
                questions: call.questions,
                notice: call.notice,
                onEnd: { callCenter.endActiveCall() }
            )
        } else if let simulatedContact {
            CallView(
                peerName: simulatedContact.name,
                phase: simulatedPhase,
                questions: environment.family.questions(for: simulatedContact).map(\.text),
                notice: "체험 모드입니다. 통화 화면만 미리 보여드려요",
                onEnd: endSimulatedCall
            )
        }
    }

    private var callPresentation: Binding<Bool> {
        Binding(
            get: { callCenter.activeCall != nil || simulatedContact != nil },
            set: { isPresented in
                if !isPresented { endSimulatedCall() }
            }
        )
    }

    private var launcherNotice: String? {
        if isGuest { return "체험 모드입니다. 통화 화면만 미리 보여드려요" }
        return nil
    }

    private func syncLauncher() {
        let callable = environment.family.callableContacts
        launcher.configure(
            targets: isGuest || callable.isEmpty ? environment.family.contacts : callable,
            questions: environment.family.selectedQuestionTexts
        )
    }

    private func reselect(_ tab: MainTab) {
        let isAtRoot = navigation.isAtRoot(tab)
        navigation.popToRoot(tab)
        if isAtRoot { tabManager.reselect(tab) }
    }

    private func startCall(_ contact: FamilyContact) {
        guard !isGuest else {
            startSimulatedCall(contact)
            return
        }
        guard let userId = contact.userId else { return }
        callCenter.startOutgoingCall(
            calleeId: userId,
            name: contact.name,
            questions: environment.family.questions(for: contact).map(\.text)
        )
    }

    private func startSimulatedCall(_ contact: FamilyContact) {
        simulationTask?.cancel()
        simulatedPhase = .connecting
        simulatedContact = contact
        simulationTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            simulatedPhase = .ringing
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            simulatedPhase = .active
            Haptics.commit()
        }
    }

    private func endSimulatedCall() {
        simulationTask?.cancel()
        simulationTask = nil
        simulatedContact = nil
    }

}

#Preview {
    let environment = AppEnvironment()

    RootView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
}
