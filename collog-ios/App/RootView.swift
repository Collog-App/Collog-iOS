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
        VStack(spacing: 0) {
            Group {
                switch tabManager.selectedTab {
                case .home:
                    HomeView()
                case .report:
                    ReportTimelineView(initialTabIndex: 0)
                case .timeline:
                    ReportTimelineView(initialTabIndex: 1)
                case .settings:
                    SettingsView()
                default:
                    ComingSoonView(title: tabManager.selectedTab.title)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBarView(selection: $tabManager.selectedTab)
        }
        .background(Color.gray50)
    }
}

private struct ComingSoonView: View {
    let title: String

    var body: some View {
        Text(title)
            .subtitle_01(.gray600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray50)
    }
}

#Preview {
    let environment = AppEnvironment()

    RootView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
}
