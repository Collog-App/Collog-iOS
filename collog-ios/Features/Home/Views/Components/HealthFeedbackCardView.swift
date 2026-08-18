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
        HStack(alignment: .top, spacing: Spacing.x3) {
            AssetPlaceholder(size: 14)
                .frame(width: IconSize.chip, height: IconSize.chip)
                .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(feedback.title)
                    .caption_01_medium(.gray800)

                Text(feedback.headline)
                    .body_01_semibold(.gray900)

                Text(feedback.tags.joined(separator: " · "))
                    .caption_02_medium(.gray700)
            }

            Spacer(minLength: Spacing.x2)

            Button(action: onMoreTap) {
                AssetPlaceholder(size: IconSize.small)
            }
            .buttonStyle(.plain)
        }
        .cardSurface()
    }
}

#Preview {
    HealthFeedbackCardView(feedback: .sample)
        .padding()
        .background(Color.gray50)
}
