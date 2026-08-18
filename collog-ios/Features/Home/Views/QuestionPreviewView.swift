//
//  QuestionPreviewView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct QuestionPreviewView: View {
    let questions: [PreviewQuestion]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("오늘 나눌 이야기")
                        .headline_02(.gray900)

                    Text("부담 없이 하나씩 물어보세요. 자연스러운 대화면 충분해요.")
                        .body_03_medium(.gray800)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.x5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.card))

                ForEach(Array(uniqueQuestions.enumerated()), id: \.element.id) { index, question in
                    HStack(alignment: .top, spacing: Spacing.x4) {
                        Text("\(index + 1)")
                            .body_02_semibold(.green700)
                            .frame(width: 32, height: 32)
                            .background(Color.green100, in: Circle())

                        Text(question.text)
                            .body_01_medium(.gray900)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .cardSurface(padding: Spacing.x5)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "오늘의 질문")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var uniqueQuestions: [PreviewQuestion] {
        questions.reduce(into: [PreviewQuestion]()) { result, question in
            guard !result.contains(where: { $0.text == question.text }) else { return }
            result.append(question)
        }
    }
}

#Preview {
    NavigationStack {
        QuestionPreviewView(questions: PreviewQuestion.samples)
    }
}
