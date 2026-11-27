//
//  SettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

private enum SettingsRoute: Hashable {
    case account
    case healthProfile
    case familyMembers
    case familySharing
}

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(CallCenter.self) private var callCenter
    @Environment(NavigationStore.self) private var navigation
    @Environment(TabManager.self) private var tabManager
    @Environment(\.openURL) private var openURL

    @State private var showsInvitationCode = false
    @State private var showsPaywall = false

    private let privacyPolicyURL = URL(string: "https://collog-app.github.io/Collog-Privacy/")!

    var body: some View {
        @Bindable var settings = environment.settings
        @Bindable var navigator = navigation.manager(for: .settings)

        return NavigationStack(path: $navigator.path) {
            CollapsingHeaderScrollView(
                title: "설정",
                scrollReset: tabManager.reselectionCount
            ) {
                EmptyView()
            } content: {
                VStack(spacing: Spacing.x6) {
                    // 역할과 상관없이 아직 아무와도 연결되지 않은 사람에게 맨 위에서 바로 보인다
                    if environment.family.canEnterInvitationCode(using: environment) {
                        invitationCodeEntry
                    }

                    if settings.isGuestMode {
                        demoSection
                    }

                    accountSection

                    SettingsSection(title: "알림") {
                        SettingsToggleRow(
                            label: "통화 알림",
                            caption: "가족이 전화하면 잠금화면에 띄워요",
                            isOn: $settings.callNotificationsEnabled
                        )
                        DividerLine()
                        SettingsToggleRow(
                            label: "리포트 알림",
                            caption: "새 통화 기록이 준비되면 알려드려요",
                            isOn: $settings.reportNotificationsEnabled
                        )
                        if let error = callCenter.deviceRegistrationError {
                            Text(error)
                                .caption_01_medium(.red500)
                                .padding(Spacing.x4)
                        }
                        if let error = callCenter.notificationPermissionError {
                            Text(error)
                                .caption_01_medium(.red500)
                                .padding(Spacing.x4)
                        }
                    }

                    SettingsSection(title: "통화") {
                        SettingsToggleRow(
                            label: "질문 음성 안내",
                            caption: "상대가 전화를 받기 전에 오늘의 질문을 읽어줘요",
                            isOn: $settings.questionVoiceEnabled
                        )
                    }

                    SettingsSection(title: "정보") {
                        SettingsNavigationRow(label: "개인정보처리방침") {
                            openURL(privacyPolicyURL)
                        }
                    }

                    footer
                }
                .padding(.horizontal, Spacing.x5)
                .padding(.bottom, Spacing.x8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.navigationManager, navigator)
            .navigationDestination(for: SettingsRoute.self) { route in
                settingsDestination(for: route)
            }
            .sheet(isPresented: $showsInvitationCode) {
                InvitationAcceptSheet()
            }
            .sheet(isPresented: $showsPaywall) {
                PaywallView()
            }
        }
    }

    private var invitationCodeEntry: some View {
        Button {
            showsInvitationCode = true
        } label: {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("초대 코드 입력")
                        .body_01_semibold(.gray900)

                    Text("가족에게 받은 6자리 코드를 넣으면 바로 연결돼요")
                        .caption_01_medium(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.x2)

                Icon(name: "chevron.right", size: IconSize.small, weight: .semibold, color: .greenDark)
            }
            .cardSurface()
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.green200, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(callCenter.hasCallInProgress)
    }

    private var accountSection: some View {
        SettingsSection(title: "계정") {
            SettingsNavigationRow(
                label: "계정 정보",
                value: environment.session.user?.name ?? "데모 사용자"
            ) {
                navigation.manager(for: .settings).push(SettingsRoute.account)
            }
            DividerLine()
            SettingsNavigationRow(label: "건강 프로필") {
                navigation.manager(for: .settings).push(SettingsRoute.healthProfile)
            }
            DividerLine()
            SettingsNavigationRow(label: "가족 구성원 관리") {
                navigation.manager(for: .settings).push(SettingsRoute.familyMembers)
            }
            DividerLine()
            SettingsNavigationRow(label: "가족 공유 데이터 범위") {
                navigation.manager(for: .settings).push(SettingsRoute.familySharing)
            }
            // 건강 연결 약속(11-08): 별도 선택 동의. 체험 모드에는 서버·건강 앱 읽기가 없어 두지 않는다
            if !environment.settings.isGuestMode, environment.session.isAuthenticated {
                DividerLine()
                SettingsNavigationRow(
                    label: "건강 앱 연결",
                    value: environment.health.rowText(for: environment.session.user?.id)
                ) {
                    environment.health.present()
                }
            }
            // 결제 약속: 결제가 켜져 있을 때만(꺼져 있으면 지금과 같은 앱). 체험 모드에는 서버가 없어 두지 않는다
            if !environment.settings.isGuestMode, environment.billing.showsEntryPoints,
               let entitlement = environment.billing.entitlement {
                DividerLine()
                SettingsSubscriptionRow(
                    plan: BillingStore.planText(entitlement),
                    usage: entitlement.analysis.map(BillingStore.usageText)
                ) {
                    showsPaywall = true
                }
            }
        }
    }


    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch route {
        case .account:
            AccountSettingsView()
        case .healthProfile:
            HealthProfileSettingsView()
        case .familyMembers:
            FamilyMembersSettingsView()
        case .familySharing:
            FamilySharingSettingsView()
        }
    }

    private var demoSection: some View {
        Button {
            environment.settings.isGuestMode = false
        } label: {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("DEMO")
                        .body_02_semibold(.gray900)

                    Text("예시 데이터로 둘러보는 중이에요")
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)

                Text("로그인")
                    .body_02_semibold(.greenDark)
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var footer: some View {
        if environment.session.isAuthenticated {
            Button {
                Task { await environment.signOut() }
            } label: {
                Text("로그아웃")
                    .body_02_semibold(.red500)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        Text("콜록 \(Bundle.main.appVersion)")
            .caption_01_medium(.gray700)
            .frame(maxWidth: .infinity)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    let environment = AppEnvironment()
    SettingsView()
        .environment(environment)
        .environment(CallCenter(environment: environment))
        .environment(NavigationStore())
        .environment(TabManager())
}
