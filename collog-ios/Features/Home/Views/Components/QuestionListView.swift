//
//  QuestionListView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct QuestionListView: View {
    let questions: [PreviewQuestion]
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            content
                .cardSurface()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.x5) {
            HStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("오늘의 질문")
                        .body_01_semibold(.gray900)

                    Text("통화할 때 가볍게 물어보세요")
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)

                Icon(name: "chevron.right", size: 14, color: .gray500)
            }

            floatingQuestions
        }
    }

    private var floatingQuestions: some View {
        ZStack {
            ForEach(Array(displayedQuestions.enumerated()), id: \.element.id) { index, question in
                questionPill(question.text, index: index)
                    .offset(x: horizontalOffset(for: index), y: verticalOffset(for: index))
                    .rotationEffect(.degrees(rotation(for: index)))
                    .phaseAnimator([false, true]) { content, phase in
                        content.offset(y: phase ? -3 : 3)
                    } animation: { _ in
                        .easeInOut(duration: 2.8 + Double(index) * 0.35)
                    }
            }
        }
        .frame(height: 144)
        .frame(maxWidth: .infinity)
    }

    private func questionPill(_ text: String, index: Int) -> some View {
        HStack(spacing: Spacing.x2) {
            Text(String(format: "%02d", index + 1))
                .caption_01_semibold(.green700)

            Text(text)
                .body_03_medium(.gray900)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.x4)
        .frame(height: 44)
        .background(pillColor(for: index), in: Capsule())
        .overlay {
            Capsule()
                .stroke(index == 1 ? Color.green200 : Color.gray200, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
    }

    private func pillColor(for index: Int) -> Color {
        switch index {
        case 1: .greenLight
        case 2: .greenLight
        default: .gray00
        }
    }

    private func horizontalOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: 14
        case 2: -8
        default: -12
        }
    }

    private func verticalOffset(for index: Int) -> CGFloat {
        CGFloat(index - 1) * 44
    }

    private func rotation(for index: Int) -> Double {
        switch index {
        case 1: 1.0
        case 2: -0.8
        default: -1.4
        }
    }

    private var displayedQuestions: [PreviewQuestion] {
        Array(
            questions.reduce(into: [PreviewQuestion]()) { result, question in
                guard !result.contains(where: { $0.text == question.text }) else { return }
                result.append(question)
            }
            .prefix(3)
        )
    }
}

#Preview {
    QuestionListView(questions: PreviewQuestion.samples)
        .padding(Spacing.x5)
        .background(Color.gray50)
}
