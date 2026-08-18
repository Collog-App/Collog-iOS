//
//  HealthFeedbackDetailView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HealthFeedbackDetailView: View {
    let feedback: HealthFeedback
    let summary: FamilyHealthSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                hero
                reasonCard
                checklistCard

                Text(
                    "이 내용은 의료 진단이 아니에요. "
                    + "통화에서 관찰된 내용을 가족이 살펴볼 수 있게 정리했어요."
                )
                    .caption_01_medium(.gray700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.x1)
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .navigationTitle("건강 피드백")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous)
                .fill(Color.orangeLight)
                .frame(width: 44, height: 44)
                .overlay {
                    Icon(name: "lightbulb.max", size: 20, color: .orange600)
                }

            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(feedback.headline)
                    .headline_02(.gray900)

                Text("최근 통화 기록을 가족과 함께 살펴보세요.")
                    .body_03_medium(.gray800)
            }

            HStack(spacing: Spacing.x2) {
                ForEach(feedback.tags, id: \.self) { tag in
                    Text(tag)
                        .caption_01_semibold(.gray800)
                        .padding(.horizontal, Spacing.x3)
                        .padding(.vertical, Spacing.x2)
                        .background(Color.gray00.opacity(0.86), in: Capsule())
                }
            }
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orangeLight.opacity(0.58), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("왜 표시됐나요")
                .body_01_semibold(.gray900)

            Text(summary.detail)
                .body_02_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)

            DividerLine()

            HStack(alignment: .firstTextBaseline) {
                Text(summary.trend.metricName)
                    .body_03_medium(.gray700)

                Spacer(minLength: Spacing.x2)

                Text(latestValue)
                    .body_01_semibold(.gray900)
            }
        }
        .cardSurface(padding: Spacing.x5)
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("함께 확인해보세요")
                .body_01_semibold(.gray900)

            checkRow("최근 생활에서 달라진 점이 있는지 물어보세요")
            checkRow("복약과 수면 상태를 편하게 이야기해보세요")
            checkRow("걱정이 이어지면 의료진과 상담해보세요")
        }
        .cardSurface(padding: Spacing.x5)
    }

    private func checkRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.x3) {
            Icon(name: "checkmark.circle.fill", size: 18, color: .greenDark)
            Text(text)
                .body_03_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var latestValue: String {
        guard let latest = summary.trend.latest else { return "확인 중" }
        return "\(Int(latest.value.rounded()))\(summary.trend.unit)"
    }
}

#Preview {
    NavigationStack {
        HealthFeedbackDetailView(feedback: .sample, summary: .sample)
    }
}
