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

            VStack(alignment: .leading, spacing: Spacing.x3) {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 {
                        DividerLine()
                    }

                    HStack(alignment: .top, spacing: Spacing.x3) {
                        BadgeView(label: group.category)
                            .frame(width: 56, alignment: .leading)

                        VStack(alignment: .leading, spacing: Spacing.x1) {
                            ForEach(group.items, id: \.self) { item in
                                Text(item)
                                    .body_03_medium(.gray900)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .cardSurface()
    }
}

#Preview {
    ConversationCardView(groups: WeeklyReport.sample.conversationGroups)
        .padding()
        .background(Color.gray50)
}
