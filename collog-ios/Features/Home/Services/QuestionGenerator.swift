//
//  QuestionGenerator.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import Foundation
import FoundationModels

enum QuestionGenerator {
    @MainActor
    static func generate(memberName: String, excluding existing: [String]) async -> [String] {
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.isAvailable, model.supportsLocale(Locale(identifier: "ko-KR")) {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: prompt(memberName: memberName, existing: existing))
                    let questions = parse(response.content)
                    if questions.count == 3 { return questions }
                } catch {}
            }
        }

        return fallback(excluding: existing)
    }

    @available(iOS 26.0, *)
    private static var instructions: String {
        """
        가족 간 안부 통화를 돕는 한국어 질문을 만든다.
        존댓말 질문을 정확히 3개 만든다.
        각 질문은 35자 이내로 쓰고 번호 없이 한 줄에 하나만 출력한다.
        의료 판단, 진단, 불안 조장, 기존 질문과 같은 내용은 피한다.
        자연스럽고 따뜻하지만 과장되지 않은 말투를 사용한다.
        """
    }

    @available(iOS 26.0, *)
    private static func prompt(memberName: String, existing: [String]) -> String {
        """
        \(memberName)과 다음 통화에서 나눌 새로운 질문을 만들어줘.
        아래 질문과 겹치지 않게 해줘.
        \(existing.joined(separator: "\n"))
        """
    }

    static func fallback(excluding existing: [String]) -> [String] {
        let pool = [
            "이번 주에 가장 즐거웠던 일은 무엇인가요?",
            "요즘 자주 드시는 반찬은 무엇인가요?",
            "오늘 날씨는 어떻게 느껴지셨어요?",
            "최근에 보고 싶은 사람은 누구인가요?",
            "다음에 함께 먹고 싶은 음식이 있으신가요?",
            "이번 주에 푹 주무신 날이 있었나요?",
            "요즘 집에서 즐겨 하시는 일은 무엇인가요?",
            "오늘 몸을 가볍게 움직이셨나요?",
            "최근에 많이 웃으셨던 일이 있었나요?"
        ]
        let fresh = pool.filter { !existing.contains($0) }
        let source = fresh.count >= 3 ? fresh : pool
        return Array(source.shuffled().prefix(3))
    }

    private static func parse(_ response: String) -> [String] {
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
}
