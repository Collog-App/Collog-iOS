//
//  QuestionListView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct QuestionListView: View {
    let questions: [PreviewQuestion]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text("오늘의 질문")
                .body_02_semibold(.gray900)

            VStack(alignment: .leading, spacing: Spacing.x3) {
                ForEach(questions) { question in
                    HStack(alignment: .top, spacing: Spacing.x3) {
                        Circle()
                            .fill(Color.greenNormal)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        Text(question.text)
                            .body_02_medium(.gray800)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

#Preview {
    QuestionListView(questions: PreviewQuestion.samples)
        .padding(Spacing.x5)
        .background(Color.gray50)
}
