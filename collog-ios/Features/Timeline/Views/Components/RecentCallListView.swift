//
//  RecentCallListView.swift
//  collog-ios
//

import SwiftUI

/// 무료로 잠긴 타임라인 탭의 「최근 통화」(결제 약속 11-28): 통화별 분석 화면으로 가는 길.
/// 줄마다 날짜·시각·통화 길이·분석 상태. 통화별 분석 결과는 참여한 두 사람에게만 열려, 내가 참여한 통화만 누를 수 있다.
struct RecentCallListView: View {
    static let title = "최근 통화"
    static let emptyText = "아직 통화 기록이 없어요"

    let calls: [CallSummaryDTO]
    let userId: String?
    let onOpen: (CallSummaryDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(Self.title)
                .body_01_semibold(.gray900)
                .padding(.horizontal, Spacing.x1)

            if calls.isEmpty {
                Text(Self.emptyText)
                    .body_02_medium(.gray700)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.x6)
                    .cardSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(calls.enumerated()), id: \.element.id) { index, call in
                        if index > 0 { DividerLine() }
                        row(call)
                    }
                }
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func row(_ call: CallSummaryDTO) -> some View {
        let canOpen = call.involves(userId)
        Button {
            onOpen(call)
        } label: {
            HStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dateText(call.startedAt))
                        .body_02_medium(.gray900)
                    Text([Self.durationText(call.durationSec), Self.statusText(call)].compactMap { $0 }.joined(separator: " · "))
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)

                if canOpen {
                    Icon(name: "chevron.right", size: IconSize.small, color: .gray600)
                }
            }
            .padding(.horizontal, Spacing.x4)
            .padding(.vertical, Spacing.x3)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
    }

    // MARK: - 표시

    /// 「11월 27일 (목) 오후 3:12」(한국 시간).
    static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일 (E) a h:mm"
        return formatter
    }()

    /// 1분 미만은 초, 그 위는 분(버림). 길이를 모르면 nil.
    static func durationText(_ seconds: Int?) -> String? {
        guard let seconds else { return nil }
        return seconds < 60 ? "\(max(seconds, 0))초" : "\(seconds / 60)분"
    }

    static func statusText(_ call: CallSummaryDTO) -> String {
        switch call.state {
        case "ANALYZED": "분석 완료"
        case "ENDED", "PROCESSING": call.recorded ? "분석 중" : "분석 안 함"
        case "ANALYSIS_EXCLUDED":
            if call.isAnalysisQuotaExceeded {
                "이번 달 분석 시간 초과"
            } else {
                call.recorded ? "짧아서 분석 제외" : "분석 안 함"
            }
        case "ANALYSIS_FAILED": "분석 실패"
        default: "분석 안 함"
        }
    }
}
