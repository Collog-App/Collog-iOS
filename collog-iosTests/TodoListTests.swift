//
//  TodoListTests.swift
//  collog-ios
//

import Foundation
import Testing
@testable import collog_ios

@MainActor
struct TodoListTests {
    private func decode(_ json: String) throws -> TodoListResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            return try #require(Date.fromCollogTimestamp(raw))
        }
        return try decoder.decode(TodoListResponse.self, from: Data(json.utf8))
    }

    @Test func decodesSourceDoneAndNullDoneAt() throws {
        let response = try decode("""
        {"date":"2026-11-15","items":[
          {"id":"a","title":"산책","source":"SUGGESTED","done":false,"doneAt":null,"createdAt":"2026-11-15T00:00:00Z"},
          {"id":"b","title":"약 먹기","source":"USER","done":true,"doneAt":"2026-11-15T01:00:00.5Z","createdAt":"2026-11-15T00:10:00Z"}
        ]}
        """)
        #expect(response.items.map(\.source) == [.suggested, .user])
        #expect(response.items[0].doneAt == nil)
        #expect(response.items[1].done)
        #expect(response.items[1].doneAt != nil)
    }

    @Test func addEnabledOnlyForNonBlankText() {
        let model = TodoListModel()
        #expect(!model.canAdd)
        model.draft = "   \n "
        #expect(!model.canAdd)
        model.draft = "  물 마시기  "
        #expect(model.canAdd)
        #expect(model.trimmedDraft == "물 마시기")
    }

    @Test func draftIsLimitedTo100Characters() {
        let model = TodoListModel()
        model.draft = String(repeating: "가", count: 130)
        #expect(model.draft.count == 100)
    }

    @Test func guestSamplesAreThreeSuggestedItems() {
        let samples = TodoListModel.guestSamples()
        #expect(samples.map(\.title) == ["20분 산책하기", "물 6잔 마시기", "자기 전 5분 스트레칭"])
        #expect(samples.allSatisfy { $0.source == .suggested && !$0.done })
    }
}
