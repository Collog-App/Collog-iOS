//
//  MetricTrendRowView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct MetricTrend: Identifiable {
    enum Shape {
        case bar
        case line
    }

    let id = UUID()
    let label: String
    let value: String
    let unit: String
    let values: [Double]
    let shape: Shape
}

struct MetricTrendRowView: View {
    let trend: MetricTrend

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(trend.label)
                    .caption_01_medium(.gray800)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(trend.value)
                        .pretendard(.semiBold, 24, .gray900)
                    Text(trend.unit)
                        .body_02_medium(.gray800)
                }
            }

            Spacer(minLength: Spacing.x3)

            Group {
                switch trend.shape {
                case .bar:
                    SparkBarView(values: trend.values)
                case .line:
                    SparkLineView(values: trend.values)
                }
            }
            .frame(width: 96, height: 40)
        }
        .cardSurface()
    }
}

#Preview {
    VStack(spacing: 8) {
        MetricTrendRowView(
            trend: MetricTrend(
                label: "기침", value: "4", unit: "회",
                values: [1, 1, 2, 2, 3, 4], shape: .bar
            )
        )
        MetricTrendRowView(
            trend: MetricTrend(
                label: "말씀 속도", value: "208", unit: "음절/분",
                values: [229, 205, 212, 209, 216, 208], shape: .line
            )
        )
    }
    .padding(Spacing.x5)
    .background(Color.gray50)
}
