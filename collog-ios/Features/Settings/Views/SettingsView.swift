//
//  SettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: Spacing.x6) {
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
                .padding(.top, Spacing.x2)
                .padding(.bottom, Spacing.x8)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.gray50)
    }

    private var header: some View {
        HStack {
            Text("설정")
                .subtitle_01(.gray900)
            Spacer()
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x2)
        .padding(.bottom, Spacing.x4)
    }

    private var accountSection: some View {
        SettingsSection(title: "계정") {
            SettingsNavigationRow(label: "계정 정보", value: environment.session.user?.name ?? "로그인 필요")
            DividerLine()
            SettingsNavigationRow(label: "나의 건강 프로필")
            DividerLine()
            SettingsNavigationRow(label: "가족 구성원 관리")
            DividerLine()
            SettingsNavigationRow(label: "가족 공유 데이터 범위")
        }
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
            .caption_02_medium(.gray700)
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
}
