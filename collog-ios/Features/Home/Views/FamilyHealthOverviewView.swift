//
//  FamilyHealthOverviewView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct FamilyHealthOverviewView: View {
    let summary: FamilyHealthSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                statusCard

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text("최근 6주")
                        .body_01_semibold(.gray900)

                    TrendChartView(series: summary.trend)
                }
                .cardSurface(padding: Spacing.x5)

                StatTileRowView(stats: summary.stats)
                    .cardSurface(padding: Spacing.x5)

                HStack(alignment: .top, spacing: Spacing.x3) {
                    Icon(name: "info.circle", size: 18, color: .gray700)

                    Text(
                        "통화 기록에서 확인한 변화예요. "
                        + "건강 상태가 걱정되면 의료진과 상담해보세요."
                    )
                        .caption_01_medium(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.x4)
                .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnXsmall))
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "가족 건강")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text(summary.memberName)
                .caption_01_semibold(.green700)

            Text(summary.headline)
                .headline_02(.gray900)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary.detail)
                .body_03_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.greenLightActive.opacity(0.76), .green100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
    }
}

#Preview {
    NavigationStack {
        FamilyHealthOverviewView(summary: .sample)
    }
}
