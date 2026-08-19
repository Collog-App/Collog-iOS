//
//  AccountSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x5) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(displayName)
                        .subtitle_01(.gray900)

                    Text(roleText)
                        .body_03_medium(.gray700)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()

                SettingsSection(title: "기본 정보") {
                    SettingsValueRow(label: "이름", value: displayName)
                    DividerLine()
                    SettingsValueRow(label: "전화번호", value: phoneText)
                    DividerLine()
                    SettingsValueRow(label: "역할", value: roleText)
                }

                SettingsSection(title: "가족") {
                    SettingsValueRow(label: "등록된 가족", value: "\(environment.family.contacts.count)명")
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "계정 정보")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var displayName: String {
        environment.session.user?.name ?? "데모 사용자"
    }

    private var phoneText: String {
        environment.session.user?.phone ?? "010-0000-0000"
    }

    private var roleText: String {
        environment.session.user?.role == UserRoleOption.parent.rawValue ? "부모" : "자녀"
    }
}

struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.x3) {
            Text(label)
                .body_02_medium(.gray800)

            Spacer(minLength: Spacing.x3)

            Text(value)
                .body_02_medium(.gray900)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.x4)
        .frame(minHeight: 52)
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView()
            .environment(AppEnvironment())
    }
}
