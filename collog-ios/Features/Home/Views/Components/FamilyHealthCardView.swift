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

                HStack(spacing: Spacing.x1) {
                    AssetPlaceholder(size: IconSize.small)
                    Text(summary.location)
                        .caption_01_medium(.gray700)
                }
            }

            statusSection

            chartSection

            DividerLine()

            seeAllButton
        }
        .cardSurface()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(summary.statusPrefix)
                .body_02_medium(.gray800)

            Text(summary.statusHeadline)
                .body_01_semibold(.gray900)

            HStack(spacing: Spacing.x1) {
                Text(summary.highlight.prefix)
                    .caption_01_medium(.gray700)
                Text(summary.highlight.value)
                    .caption_01_semibold(.greenNormal)
                Text(summary.highlight.suffix)
                    .caption_01_medium(.gray700)
            }
            .padding(.top, Spacing.x1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            AssetPlaceholder(height: 73)

            HStack {
                Text(summary.chartStartLabel)
                    .caption_02_medium(.gray700)
                Spacer()
                Text(summary.chartEndLabel)
                    .caption_02_medium(.gray700)
            }
        }
    }

    private var seeAllButton: some View {
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
}

#Preview {
    FamilyHealthCardView(summary: .sample)
        .padding()
        .background(Color.gray50)
}
