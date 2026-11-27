//
//  CallAnalysisView.swift
//  collog-ios
//

import SwiftUI

/// 통화 분석 화면을 탭의 화면 스택에 넣을 때 쓰는 값.
struct CallAnalysisRoute: Hashable {
    let callId: String
}

/// 통화 하나의 분석. 응급 안내(11-08 가드레일)는 분석 내용보다 위에 둔다.
struct CallAnalysisView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: CallAnalysisViewModel
    @State private var showsPaywall = false

    init(callId: String) {
        _viewModel = State(initialValue: CallAnalysisViewModel(callId: callId))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.gray50)
            .safeAreaInset(edge: .top, spacing: 0) {
                HomeDetailHeader(title: "통화 분석")
            }
            .toolbar(.hidden, for: .navigationBar)
            .interactivePopGestureEnabled()
            .task { await viewModel.load(using: environment) }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .pending:
            EmptyStateView(
                symbol: "waveform",
                title: "통화를 분석하고 있어요.",
                message: "분석이 끝나면 건강 관련 정보를 보여드릴게요. 잠시 뒤 다시 확인해 주세요.",
                actionTitle: "새로고침",
                action: reload
            )
        case let .unavailable(title, message, safetyNotice, summary):
            ScrollView {
                VStack(spacing: 0) {
                    if let safetyNotice {
                        SafetyNoticeCardView(text: safetyNotice)
                            .padding(.horizontal, Spacing.x5)
                            .padding(.top, Spacing.x4)
                    }
                    if let summary {
                        CallSummaryCardView(text: summary)
                            .padding(.horizontal, Spacing.x5)
                            .padding(.top, Spacing.x4)
                    }
                    EmptyStateView(symbol: "exclamationmark.circle", title: title, message: message)
                }
            }
        case .quotaExceeded:
            // 이미 프리미엄이면 버튼 없이 다음 달 안내
            let isPremium = environment.billing.entitlement?.isPremium == true
            EmptyStateView(
                symbol: "exclamationmark.circle",
                title: "분석 대상에서 제외된 통화예요.",
                message: AnalysisQuota.text(isPremium: isPremium),
                actionTitle: isPremium ? nil : BillingStore.learnMoreTitle,
                action: { showsPaywall = true }
            )
        case let .error(message):
            EmptyStateView(
                symbol: "exclamationmark.circle",
                title: "데이터를 불러오지 못했어요.",
                message: message,
                actionTitle: "다시 시도",
                action: reload
            )
        case let .ready(entry):
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    if let safetyNotice = entry.safetyNotice {
                        SafetyNoticeCardView(text: safetyNotice)
                            .padding(.bottom, Spacing.x3)
                    }
                    if let summary = entry.summary {
                        CallSummaryCardView(text: summary)
                            .padding(.bottom, Spacing.x3)
                    }
                    CallTimelineDateHeader(entry: entry)
                    CallTimelineCardView(entry: entry)
                }
                .padding(.horizontal, Spacing.x5)
                .padding(.vertical, Spacing.x4)
            }
        }
    }

    private func reload() {
        Task { await viewModel.load(using: environment) }
    }
}

/// 「통화 요약」: 통화에서 나눈 이야기를 한두 문장으로 보인다. 응급 안내 다음, 분석 내용보다 위에 둔다.
private struct CallSummaryCardView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("통화 요약")
                .caption_01_medium(.gray700)

            Text(text)
                .body_02_medium(.gray900)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        }
    }
}
