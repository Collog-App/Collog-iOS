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
                comparisonCard

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    Text(summary.periodText)
                        .body_01_semibold(.gray900)

                    TrendChartView(series: summary.trend)
                }
                .cardSurface(padding: Spacing.x5)

                insightCard

                StatTileRowView(stats: summary.stats)
                    .cardSurface(padding: Spacing.x5)
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
        .background(Color.green100, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("변화 요약")
                .body_01_semibold(.gray900)

            HStack(alignment: .top, spacing: 0) {
                comparisonItem("첫 기록", value: firstValue)
                comparisonDivider
                comparisonItem("최근 기록", value: latestValue)
                comparisonDivider
                comparisonItem("변화", value: changeText)
            }
        }
        .cardSurface(padding: Spacing.x5)
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text("이번 주 해석")
                .body_01_semibold(.gray900)

            Text(interpretation)
                .body_03_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green100, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func comparisonItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(label)
                .caption_01_medium(.gray700)

            Text(value)
                .body_01_semibold(.gray900)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonDivider: some View {
        DividerLine(axis: .vertical)
            .padding(.horizontal, Spacing.x3)
    }

    private var firstValue: String {
        formattedValue(summary.trend.points.first)
    }

    private var latestValue: String {
        formattedValue(summary.trend.latest)
    }

    private var changeText: String {
        guard let changeRate else { return "-" }
        return String(format: "%+.1f%%", changeRate)
    }

    private var changeRate: Double? {
        guard
            let first = summary.trend.points.first?.value,
            let latest = summary.trend.latest?.value,
            first != 0
        else { return nil }
        return (latest - first) / abs(first) * 100
    }

    private var interpretation: String {
        guard let latest = summary.trend.latest else {
            return "통화 기록이 더 모이면 자세히 알려드릴게요."
        }
        let status = summary.trend.isWithinNormalRange(latest)
            ? "평소 범위 안에 있어요."
            : "평소 범위를 벗어난 값이 확인됐어요."
        guard let changeRate else { return "\(summary.trend.metricName)은 \(status)" }
        let direction = changeRate >= 0 ? "높아졌어요" : "낮아졌어요"
        let amount = String(format: "%.1f%%", abs(changeRate))
        return "\(summary.trend.metricName)은 \(status) 첫 기록보다 \(amount) \(direction)."
    }

    private func formattedValue(_ point: TrendPoint?) -> String {
        guard let point else { return "-" }
        return "\(Int(point.value.rounded()))\(summary.trend.unit)"
    }
}

#Preview {
    NavigationStack {
        FamilyHealthOverviewView(summary: .sample)
    }
}
