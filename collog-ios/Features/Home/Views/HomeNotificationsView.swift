//
//  HomeNotificationsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HomeNotificationsView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                VStack(spacing: 0) {
                    Toggle("통화 알림", isOn: $settings.callNotificationsEnabled)
                        .pretendardStyle(.medium, 14, .gray900)
                        .padding(Spacing.x4)

                    DividerLine()
                        .padding(.leading, Spacing.x4)

                    Toggle("리포트 알림", isOn: $settings.reportNotificationsEnabled)
                        .pretendardStyle(.medium, 14, .gray900)
                        .padding(Spacing.x4)
                }
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card))

                Text("최근 알림")
                    .body_01_semibold(.gray900)
                    .padding(.leading, Spacing.x1)

                VStack(spacing: Spacing.x3) {
                    notificationRow(
                        symbol: "doc.text.fill",
                        title: "이번 주 리포트가 준비됐어요",
                        message: "최근 통화에서 확인한 내용을 정리했어요.",
                        time: "오늘"
                    )

                    notificationRow(
                        symbol: "bubble.left.and.text.bubble.right.fill",
                        title: "오늘의 질문이 도착했어요",
                        message: "다음 통화에서 나눌 질문을 확인해보세요.",
                        time: "어제"
                    )
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "알림")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func notificationRow(
        symbol: String,
        title: String,
        message: String,
        time: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.x3) {
            RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous)
                .fill(Color.greenLight)
                .frame(width: 40, height: 40)
                .overlay {
                    Icon(name: symbol, size: 18, color: .green700)
                }

            VStack(alignment: .leading, spacing: Spacing.x1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .body_02_semibold(.gray900)

                    Spacer(minLength: Spacing.x2)

                    Text(time)
                        .caption_01_medium(.gray700)
                }

                Text(message)
                    .body_03_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

#Preview {
    NavigationStack {
        HomeNotificationsView()
            .environment(AppEnvironment())
    }
}
