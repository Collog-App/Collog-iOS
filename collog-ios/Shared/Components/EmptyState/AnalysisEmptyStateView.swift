//
//  AnalysisEmptyStateView.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import SwiftUI

enum AnalysisEmptyAction: Equatable {
    case processing, family, call, currentWeek, none

    static func resolve(
        calls: [CallSummaryDTO], canCall: Bool, isCurrentWeek: Bool, isGuest: Bool
    ) -> Self {
        if calls.contains(where: { $0.recorded && ["ENDED", "PROCESSING"].contains($0.state) }) {
            return .processing
        }
        if !isCurrentWeek { return .currentWeek }
        if isGuest { return .none }
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
    var calls: [CallSummaryDTO] = []
    var isCurrentWeek = true
    var onCurrentWeek: (() -> Void)?
    let onRefresh: () async -> Void

    private var action: AnalysisEmptyAction {
        .resolve(
            calls: calls, canCall: contact?.isCallable == true,
            isCurrentWeek: isCurrentWeek, isGuest: environment.settings.isGuestMode
        )
    }

    private var message: String {
        switch action {
        case .processing: "통화 분석을 준비하고 있어요. 해당 통화의 상태를 확인할 수 있어요."
        case .family: "가족을 초대하거나 받은 초대 코드를 입력해 첫 통화를 시작해 보세요."
        case .call: "가족과 통화하고 분석에 동의하면 대화 내용을 다시 살펴볼 수 있어요."
        case .currentWeek: "선택한 기간에는 분석된 통화가 없어요. 이번 주 기록을 확인해 보세요."
        case .none: "선택한 기간에 통화 분석이 완료되면 여기에 표시돼요."
        }
    }

    private var actionTitle: String? {
        switch action {
        case .processing: "통화 상태 보기"
        case .family: environment.session.user?.role == "PARENT" ? "초대 코드 입력하기" : "가족 초대하기"
        case .call: "\(contact?.name ?? "가족")에게 전화하기"
        case .currentWeek: "이번 주 보기"
        case .none: nil
        }
    }

    var body: some View {
        EmptyStateView(
            symbol: action == .processing ? "waveform" : "doc.text.magnifyingglass",
            title: action == .processing ? "통화를 분석하고 있어요." : "아직 분석된 데이터가 없어요.",
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
