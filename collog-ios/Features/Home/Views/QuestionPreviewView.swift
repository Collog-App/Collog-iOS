//
//  QuestionPreviewView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import FoundationModels
import SwiftUI

struct QuestionPreviewView: View {
    let questions: [PreviewQuestion]
    let memberName: String

    @State private var generatedQuestions: [PreviewQuestion] = []
    @State private var isGenerating = false
    @State private var generationFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("오늘 나눌 이야기")
                        .subtitle_01(.gray900)

                    Text("부담 없이 하나씩 물어보세요. 자연스러운 대화면 충분해요.")
                        .body_03_medium(.gray800)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.x5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.greenLight, in: RoundedRectangle(cornerRadius: Radius.card))

                if canGenerateQuestions {
                    generationButton
                }

                if generationFailed {
                    Text("지금은 새 질문을 만들 수 없어요. 잠시 후 다시 시도해주세요.")
                        .caption_01_medium(.gray700)
                        .padding(.horizontal, Spacing.x1)
                }

                ForEach(Array(displayedQuestions.enumerated()), id: \.element.text) { index, question in
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

    private var generationButton: some View {
        Button { generateQuestions() } label: {
            HStack(spacing: Spacing.x3) {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(generatedQuestions.isEmpty ? "새 질문 만들기" : "질문 다시 만들기")
                        .body_02_semibold(.gray900)

                    Text("기기 안에서 새로운 질문 3개를 만들어요")
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.gray700)
                } else {
                    Icon(name: "arrow.clockwise", size: 18, color: .gray700)
                }
            }
            .cardSurface(padding: Spacing.x5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    private var displayedQuestions: [PreviewQuestion] {
        generatedQuestions.isEmpty ? uniqueQuestions : generatedQuestions
    }

    private var uniqueQuestions: [PreviewQuestion] {
        questions.reduce(into: [PreviewQuestion]()) { result, question in
            guard !result.contains(where: { $0.text == question.text }) else { return }
            result.append(question)
        }
    }

    private var canGenerateQuestions: Bool {
        guard #available(iOS 26.0, *) else { return false }
        let model = SystemLanguageModel.default
        return model.isAvailable && model.supportsLocale(Locale(identifier: "ko-KR"))
    }

    private func generateQuestions() {
        guard #available(iOS 26.0, *), !isGenerating else { return }
        isGenerating = true
        generationFailed = false

        Task { @MainActor in
            defer { isGenerating = false }

            do {
                let session = LanguageModelSession(instructions: generationInstructions)
                let response = try await session.respond(to: generationPrompt)
                let generated = Self.parseQuestions(response.content)
                guard !generated.isEmpty else { throw QuestionGenerationError.emptyResponse }
                generatedQuestions = generated.map(PreviewQuestion.init(text:))
                Haptics.commit()
            } catch {
                generationFailed = true
                Haptics.cancel()
            }
        }
    }

    @available(iOS 26.0, *)
    private var generationInstructions: String {
        """
        가족 간 안부 통화를 돕는 한국어 질문을 만든다.
        존댓말 질문을 정확히 3개 만든다.
        각 질문은 35자 이내로 쓰고 번호 없이 한 줄에 하나만 출력한다.
        의료 판단, 진단, 불안 조장, 기존 질문과 같은 내용은 피한다.
        자연스럽고 따뜻하지만 과장되지 않은 말투를 사용한다.
        """
    }

    @available(iOS 26.0, *)
    private var generationPrompt: String {
        let existing = uniqueQuestions.map(\.text).joined(separator: "\n")
        return """
        \(memberName)과 다음 통화에서 나눌 새로운 질문을 만들어줘.
        아래 질문과 겹치지 않게 해줘.
        \(existing)
        """
    }

    private static func parseQuestions(_ response: String) -> [String] {
        let prohibitedTerms = [
            "축", "결", "흐름", "붙는다", "박다", "아니라", "않습니다", "않는다",
            "기준", "지점", "아픈", "전환점", "닫다", "열다", "굴리다", "두께", "쪽"
        ]

        return response
            .split(whereSeparator: \.isNewline)
            .map { stripListPrefix(String($0)) }
            .filter { !$0.isEmpty }
            .filter { question in
                !prohibitedTerms.contains { question.contains($0) }
            }
            .reduce(into: [String]()) { result, question in
                guard !result.contains(question) else { return }
                result.append(question)
            }
            .prefix(3)
            .map { $0 }
    }

    private static func stripListPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.drop { character in
            character.isNumber || character.isWhitespace || ".-):".contains(character)
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum QuestionGenerationError: Error {
        case emptyResponse
    }
}

#Preview {
    NavigationStack {
        QuestionPreviewView(questions: PreviewQuestion.samples, memberName: "어머니")
    }
}
