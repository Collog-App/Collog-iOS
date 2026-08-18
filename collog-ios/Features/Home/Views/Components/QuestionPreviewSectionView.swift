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
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text("다음 통화 전 미리 확인해보세요")
                .caption_01_medium(.gray800)

            ForEach(questions) { question in
                row(for: question)
            }

            Button(action: onListenTap) {
                Text("통화 시작 전 질문 듣기")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.x1)
        }
    }

    private func row(for question: PreviewQuestion) -> some View {
        HStack(spacing: Spacing.x3) {
            AssetPlaceholder(size: 13)
                .frame(width: IconSize.medium, height: IconSize.medium)
                .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))

            Text(question.text)
                .body_02_medium(.gray900)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .cardSurface(padding: Spacing.x4, cornerRadius: Radius.btnSmall)
    }
}

#Preview {
    QuestionPreviewSectionView(questions: PreviewQuestion.samples)
        .padding()
        .background(Color.gray50)
}
