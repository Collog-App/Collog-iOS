//
//  HomeViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class HomeViewModel {
    private(set) var healthSummary: FamilyHealthSummary?
    private(set) var healthFeedback: HealthFeedback?
    private(set) var lastCallText = "아직 통화 기록이 없어요"
    private(set) var isLoaded = true
    private(set) var loadError: String?
    private(set) var recentCalls: [CallSummaryDTO] = []
    private(set) var recentCallsError: String?
    /// 고른 가족이 나에게 리포트 공유를 껐다(서버 403). 오류가 아니라 볼 수 없는 항목으로 보인다.
    private(set) var isReportNotShared = false
    @ObservationIgnored private var generation = UUID()

    static let callsNotSharedText = "통화 기록을 공유하지 않았어요"

    /// 화면을 비우지 않고 통화 목록만 다시 읽는다(앱 복귀·통화 종료 때). 분석 완료 건수가 바뀌었거나 아직 결과 카드가 없으면 전체를 다시 읽는다.
    func refreshCalls(using environment: AppEnvironment, contact: FamilyContact?) async {
        guard !environment.settings.isGuestMode, environment.session.isAuthenticated,
              let parentId = contact?.userId,
              let calls = try? await environment.api.calls(parentId: parentId) else { return }
        let analyzedBefore = recentCalls.filter(\.isAnalyzed).count
        recentCalls = calls
        recentCallsError = nil
        lastCallText = Self.lastCallText(calls: calls)
        if calls.filter(\.isAnalyzed).count != analyzedBefore || healthSummary == nil {
            await refresh(using: environment, contact: contact)
        }
    }

    func refresh(
        using environment: AppEnvironment,
        contact: FamilyContact?
    ) async {
        let generation = UUID()
        self.generation = generation
        isLoaded = false
        defer {
            if self.generation == generation { isLoaded = true }
        }
        healthSummary = nil
        healthFeedback = nil
        loadError = nil
        recentCalls = []
        recentCallsError = nil
        isReportNotShared = false
        lastCallText = "아직 통화 기록이 없어요"
        if environment.settings.isGuestMode {
            healthSummary = .sample(for: contact)
            healthFeedback = .sample(for: contact)
            lastCallText = contact?.lastCallText.appending("했어요") ?? "최근 통화했어요"
            isLoaded = true
            return
        }

        guard environment.session.isAuthenticated else { return }
        // 리포트 대상은 고른 가족이다
        guard let parentId = contact?.userId else { return }

        let api = environment.api
        let calls: [CallSummaryDTO]
        var callsNotShared = false
        do {
            calls = try await api.calls(parentId: parentId)
        } catch let error as APIError where error.isForbidden {
            // 타임라인 공유를 끈 가족의 통화 기록은 오류가 아니다
            callsNotShared = true
            calls = []
        } catch {
            guard self.generation == generation else { return }
            recentCallsError = error.localizedDescription
            calls = []
        }
        guard self.generation == generation else { return }
        recentCalls = calls
        if callsNotShared {
            lastCallText = Self.callsNotSharedText
        } else {
            lastCallText = recentCallsError == nil
                ? Self.lastCallText(calls: calls) : "통화 기록을 불러오지 못했어요"
        }

        let baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [String: BaselineDTO]()) { $0[$1.metric] = $1 }

        let dto: ReportDTO
        do {
            dto = try await api.report(parentId: parentId)
        } catch let error as APIError where error.isForbidden {
            if self.generation == generation { isReportNotShared = true }
            return
        } catch {
            if self.generation == generation { loadError = error.localizedDescription }
            return
        }
        guard self.generation == generation else { return }
        healthSummary = FamilyHealthSummary(
            dto: dto,
            memberName: contact?.name ?? "가족",
            baseline: baselines["SPEECH_RATE"]
        )
        healthFeedback = HealthFeedback(dto: dto)
    }

    private static func lastCallText(calls: [CallSummaryDTO]) -> String {
        guard let latest = calls.max(by: { $0.startedAt < $1.startedAt }) else {
            return "아직 통화 기록이 없어요"
        }

        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latest.startedAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        return switch days {
        case ..<1: "오늘 통화했어요"
        case 1: "어제 통화했어요"
        case 2: "그저께 통화했어요"
        default: "\(days)일 전에 통화했어요"
        }
    }
}
