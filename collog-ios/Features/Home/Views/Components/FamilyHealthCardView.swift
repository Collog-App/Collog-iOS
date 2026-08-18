//
//  FamilyHealthCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct FamilyHealthCardView: View {
    let summary: FamilyHealthSummary
    var onSeeAllTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack(spacing: Spacing.x2) {
                BadgeView(label: summary.memberName)
                Spacer(minLength: Spacing.x2)
                Text(summary.periodText)
                    .caption_01_medium(.gray700)
            }

            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text(summary.headline)
                    .body_01_semibold(.gray900)
                Text(summary.detail)
                    .caption_01_medium(.gray800)
            }

            TrendChartView(series: summary.trend)

            DividerLine()

            StatTileRowView(stats: summary.stats)

            DividerLine()

            Button(action: onSeeAllTap) {
                HStack(spacing: Spacing.x1) {
                    Text("가족 모두 보기")
                        .body_02_semibold(.gray800)
                    Spacer()
                    AssetPlaceholder(size: IconSize.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .cardSurface()
    }
}

#Preview {
    ScrollView {
        FamilyHealthCardView(summary: .sample)
            .padding()
    }
    .background(Color.gray50)
}
