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
                if !summary.conversationGroups.isEmpty {
                    Text("나눈 이야기")
                        .caption_01_semibold(.gray700)
                    ForEach(summary.conversationGroups.prefix(2)) { group in
                        if let item = group.items.first {
                            Text(item)
                                .body_02_medium(.gray900)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if isLoaded, let trend = summary.trend {
                    SparkLineView(values: trend.points.map(\.value), lineWidth: 2.5)
                        .frame(height: 56)
                } else if !isLoaded {
                    RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous)
                        .fill(Color.gray100)
                        .frame(height: 56)
                } else if summary.conversationGroups.isEmpty {
                    Text("이번 기간의 통화에서 정리할 대화 항목을 찾지 못했어요.")
                        .body_03_medium(.gray700)
                }
                Text("통화 기록 자세히 보기")
                    .caption_01_semibold(.greenDark)
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
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(summary.headline)
                    .subtitle_01(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Text(summary.detail)
                    .body_03_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let trend = summary.trend, let latest = trend.latest {
                HStack(alignment: .lastTextBaseline, spacing: Spacing.x1) {
                    Text("\(Int(latest.value.rounded()))")
                        .pretendard(.semiBold, 24, .gray900)

                    Text(trend.unit)
                        .body_03_medium(.gray800)

                    Spacer(minLength: Spacing.x2)

                    Text(trend.hasPersonalBaseline
                         ? (trend.isWithinNormalRange(latest) ? "평소 범위" : "평소와 다름")
                         : "비교할 기록 수집 중")
                        .caption_01_semibold(
                            trend.hasPersonalBaseline
                                ? (trend.isWithinNormalRange(latest) ? .green700 : .orange600) : .gray700
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

}

#Preview {
    HealthStatusCardView(summary: .sample)
        .padding(Spacing.x5)
        .background(Color.gray50)
}
