//
//  ConversationCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ConversationCardView: View {
    let groups: [ConversationGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("나눈 이야기")
                .caption_01_medium(.gray800)

            VStack(alignment: .leading, spacing: Spacing.x4) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        DividerLine()
                    }

                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        HStack(spacing: Spacing.x2) {
                            Icon(name: group.symbol, size: 15, color: .gray700)

                            Text(group.category)
                                .caption_01_semibold(.gray700)
                        }

                        VStack(alignment: .leading, spacing: Spacing.x1) {
                            ForEach(group.items, id: \.self) { item in
                                Text(item)
                                    .body_02_medium(.gray900)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .cardSurface()
    }
}

#Preview {
    ConversationCardView(groups: WeeklyReport.sample.conversationGroups)
        .padding(Spacing.x5)
        .background(Color.gray50)
}
