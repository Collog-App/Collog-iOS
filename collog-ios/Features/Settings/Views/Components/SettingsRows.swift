//
//  SettingsRows.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(title)
                .caption_01_medium(.gray800)
                .padding(.horizontal, Spacing.x1)

            VStack(spacing: 0) {
                content
            }
            .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }
}

struct SettingsNavigationRow: View {
    let label: String
    var value: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x2) {
                Text(label)
                    .body_02_medium(.gray900)

                Spacer(minLength: Spacing.x2)

                if let value {
                    Text(value)
                        .caption_01_medium(.gray700)
                }

                Icon(name: "chevron.right", size: IconSize.small, color: .gray600)
            }
            .padding(.horizontal, Spacing.x4)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    let label: String
    var caption: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Spacing.x2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .body_02_medium(.gray900)
                if let caption {
                    Text(caption)
                        .caption_02_medium(.gray700)
                }
            }

            Spacer(minLength: Spacing.x2)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.greenNormal)
        }
        .padding(.horizontal, Spacing.x4)
        .frame(minHeight: 52)
    }
}

struct SettingsFieldRow: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(label)
                .body_02_medium(.gray900)

            TextField(placeholder, text: $text)
                .pretendardStyle(.regular, 14)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, Spacing.x3)
                .frame(height: 44)
                .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x3)
    }
}

#Preview {
    @Previewable @State var isOn = true
    @Previewable @State var text = "http://127.0.0.1:8080"

    ScrollView {
        VStack(spacing: Spacing.x6) {
            SettingsSection(title: "계정") {
                SettingsNavigationRow(label: "계정 정보", value: "김도협")
                DividerLine()
                SettingsNavigationRow(label: "가족 구성원 관리")
            }

            SettingsSection(title: "알림") {
                SettingsToggleRow(label: "통화 알림", caption: "가족이 전화하면 알려드려요", isOn: $isOn)
            }

            SettingsSection(title: "개발") {
                SettingsFieldRow(label: "서버 주소", text: $text)
            }
        }
        .padding(Spacing.x5)
    }
    .background(Color.gray50)
}
