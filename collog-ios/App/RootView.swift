//
//  RootView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(CallCenter.self) private var callCenter

    @State private var tabManager = TabManager()
    @State private var navigation = NavigationStore()
    @State private var authFlow = AuthFlowViewModel()
    @State private var launcher = CallLauncherModel()

    @State private var simulatedContact: FamilyContact?
    @State private var simulatedPhase: CallPhase = .connecting
    @State private var simulationTask: Task<Void, Never>?

    private var isGuest: Bool { environment.settings.isGuestMode }

    var body: some View {
        ZStack {
            authContent(for: authFlow.step)
        }
        .animation(.easeInOut(duration: 0.2), value: authFlow.step)
        .task { await authFlow.resolve(using: environment) }
        .onChange(of: environment.session.isAuthenticated) {
            Task { await authFlow.resolve(using: environment) }
        }
        .onChange(of: environment.settings.isGuestMode) {
            Task { await authFlow.resolve(using: environment) }
        }
        .fullScreenCover(isPresented: callPresentation) {
            callScreen
        }
        .environment(tabManager)
        .environment(navigation)
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
                Task { await authFlow.resolve(using: environment) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
        case .consent:
            ConsentView {
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
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
        }
    }

    private var mainTabs: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    tabContent
                        .id(tabManager.selectedTab)
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
                questions: call.questions.map(\.text),
                notice: call.notice,
                onEnd: { callCenter.endActiveCall() }
            )
        } else if let simulatedContact {
            CallView(
                peerName: simulatedContact.name,
                phase: simulatedPhase,
                questions: environment.family.questions(for: simulatedContact).map(\.text),
                notice: "체험 모드예요. 실제로 전화가 걸리지는 않아요",
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
        if isGuest { return "체험 모드에서는 실제로 전화가 걸리지 않아요" }
        return environment.family.callableContacts.isEmpty ? "로그인하면 실제로 전화가 걸려요" : nil
    }

    private func syncLauncher() {
        let callable = environment.family.callableContacts
        launcher.configure(
            targets: isGuest || callable.isEmpty ? environment.family.contacts : callable,
            questions: environment.family.questions.map(\.text)
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
        callCenter.startOutgoingCall(calleeId: userId, name: contact.name)
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
