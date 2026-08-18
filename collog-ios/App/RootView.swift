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
    @State private var authFlow = AuthFlowViewModel()
    @State private var launcher = CallLauncherModel()

    var body: some View {
        Group {
            switch authFlow.step {
            case .onboarding:
                OnboardingView {
                    environment.settings.onboardingCompleted = true
                    Task { await authFlow.resolve(using: environment) }
                }
            case .login:
                LoginView {
                    callCenter.registerDeviceIfPossible()
                    Task { await authFlow.resolve(using: environment) }
                }
            case .consent:
                ConsentView {
                    Task { await authFlow.resolve(using: environment) }
                }
            case .profile:
                HealthProfileSetupView {
                    Task { await authFlow.resolve(using: environment) }
                }
            case .ready:
                mainTabs
            }
        }
        .task { await authFlow.resolve(using: environment) }
        .fullScreenCover(item: Binding(get: { callCenter.activeCall }, set: { _ in })) { call in
            CallView(
                peerName: call.peerName,
                phase: call.phase,
                questions: call.questions.map(\.text),
                notice: call.notice,
                onEnd: { callCenter.endActiveCall() }
            )
        }
        .environment(tabManager)
    }

    private var mainTabs: some View {
        ZStack {
            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    onLaunch: startCall
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

    private var launcherNotice: String? {
        environment.family.callableContacts.isEmpty ? "로그인하면 실제로 전화가 걸려요" : nil
    }

    private func syncLauncher() {
        let callable = environment.family.callableContacts
        launcher.configure(
            targets: callable.isEmpty ? environment.family.contacts : callable,
            questions: environment.family.questions.map(\.text)
        )
    }

    private func startCall(_ contact: FamilyContact) {
        guard let userId = contact.userId else { return }
        callCenter.startOutgoingCall(calleeId: userId, name: contact.name)
    }
}

#Preview {
    let environment = AppEnvironment()

    RootView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
}
