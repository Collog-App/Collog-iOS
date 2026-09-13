//
//  HealthFeedbackDetailView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HealthFeedbackDetailView: View {
    let feedback: HealthFeedback

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                hero
                if feedback.followUps.isEmpty {
                    Text("이번 기간에 정리된 대화 내용이 없어요. 다음에는 요즘 일상을 편하게 이야기해보세요.")
                        .body_03_medium(.gray800)
                        .cardSurface(padding: Spacing.x5)
                } else {
                    ForEach(feedback.followUps) { followUp in
                        followUpCard(followUp)
                    }
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: feedback.title)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(feedback.headline)
                    .subtitle_01(.gray900)

                Text("통화 내용을 요약한 기록이에요. 실제 말씀과 다를 수 있으니 다음 대화에서 확인해보세요.")
                    .body_03_medium(.gray800)
            }

            HStack(spacing: Spacing.x2) {
                ForEach(feedback.tags, id: \.self) { tag in
                    Text(tag)
                        .caption_01_semibold(.gray800)
                        .padding(.horizontal, Spacing.x3)
                        .padding(.vertical, Spacing.x2)
                        .background(Color.gray00.opacity(0.86), in: Capsule())
                }
            }
        }
        .padding(Spacing.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orangeLight.opacity(0.58), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func followUpCard(_ followUp: ConversationFollowUp) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text(followUp.category)
                .body_01_semibold(.gray900)
            Text(followUp.summary)
                .body_03_medium(.gray800)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("다음에 물어볼 질문")
                    .caption_01_semibold(.gray800)
                Text(followUp.question)
                    .body_02_medium(.gray900)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface(padding: Spacing.x5)
    }

}

#Preview {
    NavigationStack {
        HealthFeedbackDetailView(feedback: .sample)
    }
}
