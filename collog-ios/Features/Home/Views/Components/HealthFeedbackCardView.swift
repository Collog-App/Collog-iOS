//
//  HealthFeedbackCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct HealthFeedbackCardView: View {
    let feedback: HealthFeedback
    var onMoreTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.x2) {
            AssetPlaceholder(size: 13.09)
                .frame(width: IconSize.medium, height: IconSize.medium)
                .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.x2) {
                HStack {
                    Text(feedback.title)
                        .body_01_semibold(.gray800)
                    Spacer(minLength: Spacing.x2)
                    Button(action: onMoreTap) {
                        AssetPlaceholder(size: IconSize.small)
                    }
                    .buttonStyle(.plain)
                }

                Text(feedback.headline)
                    .body_01_semibold(.gray900)

                HStack(spacing: Spacing.x1) {
                    ForEach(feedback.tags, id: \.self) { tag in
                        Text(tag)
                            .body_02_semibold(.gray600)
                    }
                }
            }
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity)
        .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))
    }
}

#Preview {
    HealthFeedbackCardView(feedback: .sample)
        .padding()
}
