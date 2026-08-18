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
        VStack(alignment: .leading, spacing: 0) {
            hero

            DividerLine()
                .padding(.horizontal, Spacing.x4)

            VStack(alignment: .leading, spacing: Spacing.x4) {
                if isLoaded {
                    SparkLineView(values: summary.trend.points.map(\.value), lineWidth: 2.5)
                        .frame(height: 56)
                } else {
                    RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous)
                        .fill(Color.gray100)
                        .frame(height: 56)
                }

                DividerLine()

                HStack(spacing: Spacing.x2) {
                    Text(footnote)
                        .caption_01_medium(.gray700)

                    Spacer(minLength: Spacing.x2)

                    Icon(name: "chevron.right", size: 14, color: .gray500)
                }
            }
            .padding(Spacing.x4)
            .background(Color.gray00)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gray200, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            HStack(spacing: Spacing.x2) {
                Spacer(minLength: Spacing.x2)

                Text(summary.periodText)
                    .caption_01_medium(.gray700)
            }

            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(summary.headline)
                    .headline_02(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.detail)
                    .body_03_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let latest = summary.trend.latest {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.x1) {
                    Text("\(Int(latest.value.rounded()))")
                        .pretendard(.semiBold, 24, .gray900)

                    Text(summary.trend.unit)
                        .body_03_medium(.gray800)

                    Spacer(minLength: Spacing.x2)

                    Text(summary.trend.isWithinNormalRange(latest) ? "평소 범위" : "평소와 다름")
                        .caption_01_semibold(
                            summary.trend.isWithinNormalRange(latest) ? .green700 : .orange600
                        )
                        .padding(.horizontal, Spacing.x3)
                        .padding(.vertical, Spacing.x2)
                        .background(Color.gray00.opacity(0.82), in: Capsule())
                }
            }
        }
        .padding(Spacing.x5)
        .background(Color.gray00)
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
