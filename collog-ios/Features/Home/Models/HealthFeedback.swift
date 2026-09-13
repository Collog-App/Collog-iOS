//
//  HealthFeedback.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import Foundation

struct ConversationFollowUp: Identifiable {
    let category: String
    let summary: String
    let question: String

    var id: String { category + "\n" + summary }
}

struct HealthFeedback {
    let title: String
    let headline: String
    let tags: [String]
    let followUps: [ConversationFollowUp]

    init?(dto: ReportDTO) {
        guard dto.analyzedCallCount > 0 else { return nil }
        let topics = [
            ("symptom", "몸 상태", "최근 통화에서 나눈 몸 상태 이야기는 요즘 어때요?"),
            ("medication", "복약", "최근 통화에서 나눈 약 이야기에서 더 알려주실 내용이 있어요?"),
            ("activity", "활동", "최근 통화에서 나눈 활동 이야기에서 달라진 점이 있어요?"),
            ("sleep", "수면", "최근 통화에서 나눈 수면 이야기는 요즘 어때요?")
        ]
        followUps = topics.flatMap { key, label, question in
            var seen = Set<String>()
            return (dto.conversationItems[key] ?? []).compactMap { text -> ConversationFollowUp? in
                let summary = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !summary.isEmpty, seen.insert(summary).inserted else { return nil }
                return ConversationFollowUp(category: label, summary: summary, question: question)
            }
        }
        title = "다음 통화에서 물어보기"
        headline = followUps.first.map { "지난 \($0.category) 이야기를 이어가 보세요" }
            ?? "다시 물어볼 대화 내용이 아직 없어요"
        tags = ["대화 요약", APIFormat.shortRange(from: dto.from, to: dto.to)]
    }

    private init(headline: String, tags: [String], followUps: [ConversationFollowUp]) {
        title = "다음 통화에서 물어보기"
        self.headline = headline
        self.tags = tags
        self.followUps = followUps
    }

    static let sample = HealthFeedback(
        headline: "지난 수면 이야기를 이어가 보세요",
        tags: ["예시 대화", "3일 전 통화"],
        followUps: [ConversationFollowUp(
            category: "수면",
            summary: "밤에 잠들기까지 시간이 걸렸다고 이야기했어요.",
            question: "최근 통화에서 나눈 수면 이야기는 요즘 어때요?"
        )]
    )

    static func sample(for contact: FamilyContact?) -> HealthFeedback {
        guard contact?.relation == "FATHER" else { return .sample }
        return HealthFeedback(
            headline: "지난 활동 이야기를 이어가 보세요",
            tags: ["예시 대화", "그저께 통화"],
            followUps: [ConversationFollowUp(
                category: "활동",
                summary: "집 근처에서 산책했다고 이야기했어요.",
                question: "최근 통화에서 나눈 활동 이야기에서 달라진 점이 있어요?"
            )]
        )
    }
}
