//
//  FamilyHealthCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct FamilyHealthCardView: View {
    let summary: FamilyHealthSummary
    let feedback: HealthFeedback
    var onSeeAllTap: () -> Void = {}
    var onFeedbackMoreTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            SectionHeaderView(title: "우리 가족 건강")

            VStack(alignment: .leading, spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: 10) {
                    statusSection
                    chartSection
                }

                seeAllButton
            }

            HealthFeedbackCardView(feedback: feedback, onMoreTap: onFeedbackMoreTap)
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            BadgeView(label: summary.memberName)

            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(summary.statusPrefix)
                    .body_02_medium(.gray800)

                Text(summary.statusHeadline)
                    .body_01_semibold(.gray900)

                HStack(spacing: Spacing.x1) {
                    Text(summary.highlight.prefix)
                        .body_02_semibold(.gray600)
                    Text(summary.highlight.value)
                        .body_02_semibold(.greenNormal)
                    Text(summary.highlight.suffix)
                        .body_02_semibold(.gray600)
                }
            }

            HStack(spacing: Spacing.x1) {
                AssetPlaceholder(size: IconSize.small)
                Text(summary.location)
                    .body_02_regular(.gray600)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            AssetPlaceholder(height: 73)

            HStack {
                Text(summary.chartStartLabel)
                    .caption_02_regular(.gray600)
                Spacer()
                Text(summary.chartEndLabel)
                    .caption_02_regular(.gray600)
            }
        }
    }

    private var seeAllButton: some View {
        Button(action: onSeeAllTap) {
            HStack(spacing: Spacing.x1) {
                Text("가족 모두 보기")
                    .body_02_semibold(.gray700)
                AssetPlaceholder(size: IconSize.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FamilyHealthCardView(summary: .sample, feedback: .sample)
        .padding()
}
