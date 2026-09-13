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
    @ObservationIgnored private var generation = UUID()

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
        lastCallText = "아직 통화 기록이 없어요"
        if environment.settings.isGuestMode {
            healthSummary = .sample(for: contact)
            healthFeedback = .sample(for: contact)
            lastCallText = contact?.lastCallText.appending("했어요") ?? "최근 통화했어요"
            isLoaded = true
            return
        }

        guard environment.session.isAuthenticated else { return }
        let resolvedId = if environment.session.user?.role == "PARENT" {
            environment.session.user?.id
        } else if let userId = contact?.userId {
            userId
        } else {
            await environment.subjectParentId()
        }
        guard let parentId = resolvedId else { return }

        let api = environment.api
        let calls: [CallSummaryDTO]
        do {
            calls = try await api.calls(parentId: parentId)
        } catch {
            guard self.generation == generation else { return }
            recentCallsError = error.localizedDescription
            calls = []
        }
        guard self.generation == generation else { return }
        recentCalls = calls
        lastCallText = recentCallsError == nil
            ? Self.lastCallText(calls: calls) : "통화 기록을 불러오지 못했어요"

        let baselines = ((try? await api.baselines(parentId: parentId)) ?? [])
            .filter { $0.kind == "ROLLING" && $0.isReady }
            .reduce(into: [String: BaselineDTO]()) { $0[$1.metric] = $1 }

        let dto: ReportDTO
        do {
            dto = try await api.report(parentId: parentId)
        } catch {
            if self.generation == generation { loadError = error.localizedDescription }
            return
        }
        guard self.generation == generation else { return }
        healthSummary = FamilyHealthSummary(
            dto: dto,
            memberName: environment.session.user?.role == "PARENT"
                ? environment.session.user?.name ?? "나" : contact?.name ?? "가족",
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
