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
    @Environment(NavigationStore.self) private var navigation
    @Environment(TabManager.self) private var tabManager

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
                            caption: "주간 리포트가 준비되면 알려드려요",
                            isOn: $settings.reportNotificationsEnabled
                        )
                    }

                    SettingsSection(title: "통화") {
                        SettingsToggleRow(
                            label: "질문 음성 안내",
                            caption: "연결을 기다리는 동안 오늘의 질문을 읽어줘요",
                            isOn: $settings.questionVoiceEnabled
                        )
                    }

                    SettingsSection(title: "개발") {
                        SettingsFieldRow(
                            label: "서버 주소",
                            placeholder: AppSettings.Default.backendBaseURL,
                            text: $settings.backendBaseURL
                        )
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
        }
    }

    private var accountSection: some View {
        SettingsSection(title: "계정") {
            SettingsNavigationRow(
                label: "계정 정보",
                value: environment.session.user?.name ?? "로그인 필요"
            ) {
                navigation.manager(for: .settings).push(SettingsRoute.account)
            }
            DividerLine()
            SettingsNavigationRow(label: "나의 건강 프로필") {
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
                environment.session.signOut()
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
    SettingsView()
        .environment(AppEnvironment())
        .environment(NavigationStore())
        .environment(TabManager())
}
