//
//  AnalysisEmptyStateView.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import SwiftUI

enum AnalysisEmptyAction: Equatable {
    case processing, excluded, failed, family, call, currentWeek, none

    static func resolve(
        calls: [CallSummaryDTO], canCall: Bool, isCurrentWeek: Bool, isGuest: Bool, isSelf: Bool = false
    ) -> Self {
        if calls.contains(where: { $0.recorded && ["ENDED", "PROCESSING"].contains($0.state) }) {
            return .processing
        }
        // 실제로 통화가 이어진(1초 이상) 가장 최근 통화가 분석에서 빠졌거나 실패했을 때. 안 받은 통화는 제외한다.
        if let latest = calls.filter({ ($0.durationSec ?? 0) > 0 }).max(by: { $0.startedAt < $1.startedAt }) {
            if latest.state == "ANALYSIS_FAILED" { return .failed }
            if latest.state == "ANALYSIS_EXCLUDED" { return .excluded }
        }
        if !isCurrentWeek { return .currentWeek }
        // 「나」의 리포트에서는 나에게 전화하거나 초대하라고 권하지 않는다
        if isGuest || isSelf { return .none }
        return canCall ? .call : .family
    }
}

enum AnalysisCallStatusSnapshot {
    static func states(for calls: [CallSummaryDTO], refreshedCalls: [CallSummaryDTO]) -> [String: String] {
        calls.reduce(into: [:]) { states, call in
            states[call.id] = refreshedCalls.first {
                $0.id == call.id && $0.parentId == call.parentId
            }?.state ?? "UNAVAILABLE"
        }
    }
}

struct AnalysisEmptyStateView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(CallCenter.self) private var callCenter
    @State private var showsFamily = false
    @State private var showsCalls = false

    var contact: FamilyContact?
    var isSelf = false
    var calls: [CallSummaryDTO] = []
    var isCurrentWeek = true
    var onCurrentWeek: (() -> Void)?
    let onRefresh: () async -> Void

    private var action: AnalysisEmptyAction {
        .resolve(
            calls: calls, canCall: contact?.isCallable == true,
            isCurrentWeek: isCurrentWeek, isGuest: environment.settings.isGuestMode, isSelf: isSelf
        )
    }

    private var message: String {
        switch action {
        case .processing: "통화 분석을 준비하고 있어요. 해당 통화의 상태를 확인할 수 있어요."
        case .excluded: "부모님이 말씀하신 시간이 짧았거나(20초 미만), 두 분의 최신 동의가 확인되지 않으면 분석에서 빠져요. 조금 더 길게 통화해 보시고, 계속되면 동의 상태를 확인해 주세요."
        case .failed: "분석 중 문제가 생겼어요. 잠시 뒤 다시 확인해 주세요."
        case .family: "가족을 초대하거나 받은 초대 코드를 입력해 첫 통화를 시작해 보세요."
        case .call: "가족과 통화하고 분석에 동의하면 대화 내용을 다시 살펴볼 수 있어요."
        case .currentWeek: "선택한 기간에는 분석된 통화가 없어요. 이번 주 기록을 확인해 보세요."
        case .none: "선택한 기간에 통화 분석이 완료되면 여기에 표시돼요."
        }
    }

    private var actionTitle: String? {
        switch action {
        case .processing: "통화 상태 보기"
        case .excluded, .failed: "다시 확인하기"
        case .family: "가족 초대하기"
        case .call: "\(contact?.name ?? "가족")에게 전화하기"
        case .currentWeek: "이번 주 보기"
        case .none: nil
        }
    }

    private var symbol: String {
        switch action {
        case .processing: "waveform"
        case .excluded, .failed: "exclamationmark.circle"
        default: "doc.text.magnifyingglass"
        }
    }

    private var title: String {
        switch action {
        case .processing: "통화를 분석하고 있어요."
        case .excluded: "이 통화는 분석에서 제외됐어요."
        case .failed: "통화 분석에 실패했어요."
        default: "아직 분석된 데이터가 없어요."
        }
    }

    var body: some View {
        EmptyStateView(
            symbol: symbol,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: performAction
        )
        .sheet(isPresented: $showsFamily, onDismiss: { Task { await onRefresh() } }) {
            NavigationStack { FamilyMembersSettingsView() }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsCalls, onDismiss: { Task { await onRefresh() } }) {
            AnalysisCallStatusView(calls: calls)
        }
    }

    private func performAction() {
        switch action {
        case .processing: showsCalls = true
        case .excluded, .failed: Task { await onRefresh() }
        case .family: showsFamily = true
        case .call:
            guard let contact, let userId = contact.userId else { return }
            callCenter.startOutgoingCall(calleeId: userId, name: contact.name, questions: [])
        case .currentWeek: onCurrentWeek?()
        case .none: break
        }
    }
}

private struct AnalysisCallStatusView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var states: [String: String] = [:]
    @State private var error: String?
    @State private var isRefreshing = false
    let calls: [CallSummaryDTO]

    private var pendingCalls: [CallSummaryDTO] {
        calls.filter { $0.recorded && ["ENDED", "PROCESSING"].contains($0.state) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(pendingCalls) { call in
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text(call.startedAt.formatted(date: .abbreviated, time: .shortened))
                        Text(statusText(states[call.id] ?? call.state))
                            .body_03_medium(.gray700)
                    }
                }
                if let error { Text(error).body_03_medium(.red500) }
                Button("상태 새로고침") { Task { await refresh() } }
                    .disabled(isRefreshing)
            }
            .navigationTitle("통화 분석 상태")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
            .task { await refresh() }
        }
    }

    private func statusText(_ state: String) -> String {
        switch state {
        case "ENDED": "분석 대기 중"
        case "PROCESSING": "분석 중"
        case "ANALYZED": "분석 완료. 이전 화면에서 기록을 확인해 주세요."
        case "ANALYSIS_EXCLUDED": "분석 대상에서 제외된 통화예요."
        case "ANALYSIS_FAILED": "분석하지 못했어요."
        case "UNAVAILABLE": "삭제되었거나 더 이상 확인할 수 없는 통화예요."
        default: "분석 상태를 확인하지 못했어요."
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        error = nil
        defer { isRefreshing = false }
        do {
            var refreshedCalls: [CallSummaryDTO] = []
            for parentId in Set(pendingCalls.map(\.parentId)) {
                refreshedCalls += try await environment.api.calls(parentId: parentId)
            }
            states = AnalysisCallStatusSnapshot.states(for: pendingCalls, refreshedCalls: refreshedCalls)
        } catch { self.error = error.localizedDescription }
    }
}
