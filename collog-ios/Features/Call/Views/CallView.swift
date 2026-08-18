//
//  CallView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallView: View {
    @State private var viewModel: CallViewModel
    var onEnd: () -> Void

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(contact: FamilyContact, questions: [PreviewQuestion], onEnd: @escaping () -> Void) {
        _viewModel = State(initialValue: CallViewModel(contact: contact, questions: questions))
        self.onEnd = onEnd
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, Spacing.x8)

            questionList
                .padding(.top, Spacing.x8)

            Spacer(minLength: Spacing.x6)

            endButton
                .padding(.bottom, Spacing.x8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray50)
        .onReceive(ticker) { _ in viewModel.tick() }
    }

    private var header: some View {
        VStack(spacing: Spacing.x4) {
            Circle()
                .fill(LinearGradient.avatar)
                .frame(width: 120, height: 120)

            VStack(spacing: Spacing.x2) {
                Text(viewModel.contact.name)
                    .headline_02(.gray900)

                if viewModel.phase.showsTimer {
                    Text(viewModel.durationText)
                        .pretendard(.medium, 16, .gray700)
                        .monospacedDigit()
                } else {
                    Text(viewModel.phase.statusText)
                        .pretendard(.medium, 16, .gray700)
                }
            }
        }
    }

    private var questionList: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("오늘의 건강 질문")
                .caption_01_medium(.gray800)
                .padding(.horizontal, Spacing.x1)

            ForEach(viewModel.questions) { question in
                HStack(spacing: Spacing.x3) {
                    AssetPlaceholder(size: 13)
                        .frame(width: IconSize.medium, height: IconSize.medium)
                        .background(
                            Color.greenNormal,
                            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        )

                    Text(question.text)
                        .body_02_medium(.gray900)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .cardSurface(padding: Spacing.x3, cornerRadius: Radius.btnSmall)
            }
        }
        .padding(.horizontal, Spacing.x5)
    }

    private var endButton: some View {
        Button {
            viewModel.end()
            onEnd()
        } label: {
            AssetPlaceholder(size: 28)
                .frame(width: 72, height: 72)
                .background(Color.red500, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("통화 종료")
    }
}

#Preview {
    CallView(contact: FamilyContact.samples[0], questions: PreviewQuestion.samples) {}
}
