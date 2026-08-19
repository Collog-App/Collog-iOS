//
//  FamilySharingSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct FamilySharingSettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var agreedItems: [String] = []
    @State private var isGranted = false
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                statusCard

                SettingsSection(title: "가족에게 보이는 내용") {
                    SettingsScopeRow(
                        title: "주간 리포트",
                        detail: "말씀 속도, 통화 길이, 변화 신호"
                    )
                    DividerLine()
                    SettingsScopeRow(
                        title: "통화 요약",
                        detail: "대화 주제와 관찰 횟수"
                    )
                    DividerLine()
                    SettingsScopeRow(
                        title: "건강 피드백",
                        detail: "최근 기록에서 확인한 생활 변화"
                    )
                }

                SettingsSection(title: "기기에만 보관") {
                    SettingsScopeRow(title: "계정 인증 정보", detail: "로그인 토큰과 기기 정보")
                    DividerLine()
                    SettingsScopeRow(title: "알림 설정", detail: "개인별 알림 선택")
                }

                if !agreedItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.x3) {
                        Text("동의 항목")
                            .body_01_semibold(.gray900)

                        ForEach(agreedItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: Spacing.x2) {
                                Icon(name: "checkmark", size: 14, weight: .semibold, color: .greenDark)
                                Text(ConsentItemLabel.korean(for: item))
                                    .body_03_medium(.gray800)
                            }
                        }
                    }
                    .cardSurface()
                }

                if let errorText {
                    Text(errorText)
                        .body_03_medium(.red500)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "가족 공유 데이터 범위")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(isLoading ? "확인 중" : isGranted ? "가족과 공유 중" : "공유 대기")
                .subtitle_01(.gray900)

            Text("가족은 요약된 기록만 확인할 수 있어요.")
                .body_03_medium(.gray700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func load() async {
        defer { isLoading = false }
        if environment.settings.isGuestMode {
            agreedItems = [
                "SENSITIVE_HEALTH_COLLECTION",
                "VOICE_FEATURE_EXTRACTION",
                "CALL_RECORDING",
                "REPORT_SHARING_WITH_CHILD"
            ]
            isGranted = true
            return
        }

        do {
            let consent = try await environment.api.myConsent()
            agreedItems = consent.agreedItems
            isGranted = consent.isGranted && consent.agreedItems.contains("REPORT_SHARING_WITH_CHILD")
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct SettingsScopeRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(title)
                .body_02_medium(.gray900)

            Text(detail)
                .caption_01_medium(.gray700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        FamilySharingSettingsView()
            .environment(AppEnvironment())
    }
}
