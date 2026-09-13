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
    @State private var showsConsent = false
    @State private var confirmsRevocation = false
    @State private var isSubmitting = false

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

                SettingsSection(title: "계정과 알림") {
                    SettingsScopeRow(title: "로그인 정보", detail: "로그인 토큰은 기기 키체인에 보관돼요.")
                    DividerLine()
                    SettingsScopeRow(title: "푸시 토큰", detail: "전화와 알림 수신을 위해 서버에 등록돼요.")
                }

                if !environment.settings.isGuestMode {
                    Button("분석 동의 내용 확인 및 변경") { showsConsent = true }
                        .disabled(isLoading || isSubmitting)
                    if isGranted {
                        Button("분석 동의 철회", role: .destructive) { confirmsRevocation = true }
                            .disabled(isLoading || isSubmitting)
                    }
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
                    Button("다시 시도") { Task { await load() } }
                        .disabled(isLoading || isSubmitting)
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
        .sheet(isPresented: $showsConsent, onDismiss: { Task { await load() } }) {
            ConsentView(onAgreed: { showsConsent = false }, showsAccountActions: false)
        }
        .alert("통화 분석 동의를 철회할까요?", isPresented: $confirmsRevocation) {
            Button("취소", role: .cancel) {}
            Button("철회", role: .destructive) { Task { await revoke() } }
        } message: {
            Text("일반 통화는 계속 이용할 수 있어요. 기존 기록 삭제는 계정 관리에서 요청할 수 있어요.")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(isLoading ? "확인 중" : isGranted ? "통화 분석에 동의함" : "통화 분석 동의 없음")
                .subtitle_01(.gray900)

            Text("두 사람 모두 동의해야 통화를 녹음하고 외부 AI로 분석해요.")
                .body_03_medium(.gray700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func load() async {
        isLoading = true
        errorText = nil
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
            isGranted = consent.isCurrent && consent.isGranted
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func revoke() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            let document = try await environment.api.consentDocument()
            _ = try await environment.api.submitConsent(
                documentVersion: document.version,
                agreedItems: [],
                decision: "DENY",
                scrolledToEnd: false
            )
            await load()
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
