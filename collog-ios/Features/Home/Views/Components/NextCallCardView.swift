//
//  NextCallCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct NextCallCardView: View {
    let contact: FamilyContact
    let questions: [PreviewQuestion]
    var onCallTap: () -> Void = {}
    var onQuestionsTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            HStack(spacing: Spacing.x3) {
                Circle()
                    .fill(LinearGradient.avatar)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(contact.name)
                        .pretendard(.semiBold, 18, .gray900)
                    Text(contact.lastCallText)
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)
            }

            if let first = questions.first {
                Button(action: onQuestionsTap) {
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text("오늘의 질문")
                            .caption_01_medium(.gray800)

                        Text(first.text)
                            .body_02_medium(.gray900)
                            .multilineTextAlignment(.leading)

                        if questions.count > 1 {
                            HStack(spacing: Spacing.x1) {
                                Text("질문 \(questions.count - 1)개 더 보기")
                                    .caption_01_medium(.gray700)
                                AssetPlaceholder(size: 12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.x3)
                    .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.btnXsmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onCallTap) {
                HStack(spacing: Spacing.x2) {
                    AssetPlaceholder(size: 18)
                    Text("전화 걸기")
                        .body_01_semibold(.gray00)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    contact.isCallable ? Color.greenNormal : Color.gray500,
                    in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!contact.isCallable)

            if !contact.isCallable {
                Text("로그인하면 실제로 전화를 걸 수 있어요")
                    .caption_02_medium(.gray700)
                    .frame(maxWidth: .infinity)
            }
        }
        .cardSurface()
    }
}

#Preview {
    NextCallCardView(contact: FamilyContact.samples[0], questions: PreviewQuestion.samples)
        .padding()
        .background(Color.gray50)
}
