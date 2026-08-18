//
//  HealthStatusCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HealthStatusCardView: View {
    let summary: FamilyHealthSummary
    var isLoaded = true
    var onTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x5) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(summary.headline)
                    .pretendard(.semiBold, 20, .gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.detail)
                    .body_03_medium(.gray700)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isLoaded {
                TrendChartView(series: summary.trend)
            } else {
                RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous)
                    .fill(Color.gray100)
                    .frame(height: 132)
            }

            DividerLine()

            Button(action: onTap) {
                HStack(spacing: Spacing.x2) {
                    Text(footnote)
                        .caption_01_medium(.gray700)

                    Spacer(minLength: Spacing.x2)

                    Icon(name: "chevron.right", size: 14, color: .gray500)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footnote: String {
        summary.stats
            .map { "\($0.label) \($0.value)\($0.unit)" }
            .joined(separator: " · ")
    }
}

#Preview {
    HealthStatusCardView(summary: .sample)
        .padding(Spacing.x5)
        .background(Color.gray50)
}
