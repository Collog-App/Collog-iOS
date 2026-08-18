//
//  HomeMenuView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HomeMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.navigationManager) private var navigation

    let contact: FamilyContact?

    var body: some View {
        @Bindable var settings = environment.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                memberCard

                VStack(spacing: 0) {
                    menuRow("오늘의 질문", symbol: "bubble.left.and.text.bubble.right") {
                        navigation.push(Route.questionPreview)
                    }

                    DividerLine()
                        .padding(.leading, 56)

                    menuRow("알림", symbol: "bell") {
                        navigation.push(Route.notifications)
                    }
                }
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card))

                VStack(spacing: 0) {
                    Toggle("통화 알림", isOn: $settings.callNotificationsEnabled)
                        .pretendardStyle(.medium, 14, .gray900)
                        .padding(Spacing.x4)

                    DividerLine()
                        .padding(.leading, Spacing.x4)

                    Toggle("질문 음성 안내", isOn: $settings.questionVoiceEnabled)
                        .pretendardStyle(.medium, 14, .gray900)
                        .padding(Spacing.x4)
                }
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card))
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .navigationTitle("메뉴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var memberCard: some View {
        HStack(spacing: Spacing.x4) {
            Circle()
                .fill(LinearGradient.avatar)
                .frame(width: 52, height: 52)
                .overlay {
                    Text(String((contact?.name ?? "가족").prefix(1)))
                        .body_01_semibold(.gray900)
                }

            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(contact?.name ?? "가족")
                    .subtitle_02(.gray900)

                Text(contact?.lastCallText ?? "통화 기록을 확인해보세요")
                    .caption_01_medium(.gray700)
            }

            Spacer(minLength: 0)
        }
        .cardSurface(padding: Spacing.x5)
    }

    private func menuRow(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.x4) {
                Icon(name: symbol, size: 20, color: .gray800)
                Text(title)
                    .body_02_medium(.gray900)
                Spacer(minLength: Spacing.x2)
                Icon(name: "chevron.right", size: 14, color: .gray500)
            }
            .padding(Spacing.x4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeMenuView(contact: FamilyContact.samples.first)
            .environment(AppEnvironment())
            .environment(\.navigationManager, NavigationManager())
    }
}
