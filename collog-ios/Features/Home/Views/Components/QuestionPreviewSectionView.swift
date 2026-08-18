//
//  QuestionPreviewSectionView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct QuestionPreviewSectionView: View {
    let questions: [PreviewQuestion]
    var onListenTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("다음 통화 전 미리 확인해보세요")
                .pretendard(.medium, 15, .black)

            VStack(spacing: Spacing.x5) {
                ForEach(questions) { question in
                    row(for: question)
                }

                Button(action: onListenTap) {
                    Text("통화 시작 전 질문 듣기")
                        .pretendard(.semiBold, 15, .gray00)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Color.greenNormal,
                            in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(for question: PreviewQuestion) -> some View {
        HStack(spacing: 15) {
            AssetPlaceholder(size: 13.09)
                .frame(width: IconSize.medium, height: IconSize.medium)
                .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))

            Text(question.text)
                .pretendard(.medium, 15, .black)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.x5)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous))
    }
}

#Preview {
    QuestionPreviewSectionView(questions: PreviewQuestion.samples)
        .padding()
}
