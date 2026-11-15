//
//  TodoListModel.swift
//  collog-ios
//

import SwiftUI

/// 오늘 할 일 카드 상태. 로그인한 본인 목록만 다루며 홈에서 고른 가족과 무관하다.
@Observable
final class TodoListModel {
    static let maxTitleLength = 100

    private(set) var items: [TodoDTO] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private(set) var actionError: String?
    var draft = "" {
        didSet {
            if draft.count > Self.maxTitleLength { draft = String(draft.prefix(Self.maxTitleLength)) }
        }
    }
    @ObservationIgnored private var isGuest = false

    var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    var canAdd: Bool { !trimmedDraft.isEmpty }

    func load(using environment: AppEnvironment) async {
        isGuest = environment.settings.isGuestMode
        actionError = nil
        if isGuest {
            // 게스트는 네트워크 없이 메모리 샘플만 쓴다
            if items.isEmpty { items = Self.guestSamples() }
            loadFailed = false
            return
        }
        guard environment.session.isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await environment.api.todos().items
            loadFailed = false
        } catch is CancellationError {
        } catch {
            loadFailed = true
        }
    }

    func add(using environment: AppEnvironment) async {
        let title = trimmedDraft
        guard !title.isEmpty else { return }
        actionError = nil
        if isGuest {
            items.append(Self.guestItem(title: title, source: .user))
            draft = ""
            return
        }
        do {
            items.append(try await environment.api.createTodo(title: title))
            draft = ""
        } catch is CancellationError {
        } catch {
            actionError = "할 일을 추가하지 못했어요"
        }
    }

    func toggle(_ item: TodoDTO, using environment: AppEnvironment) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        actionError = nil
        let previous = items[index].done
        items[index].done = !previous
        guard !isGuest else { return }
        do {
            let updated = try await environment.api.setTodoDone(id: item.id, done: !previous)
            if let current = items.firstIndex(where: { $0.id == item.id }) { items[current] = updated }
        } catch {
            // 낙관적 변경을 되돌린다
            if let current = items.firstIndex(where: { $0.id == item.id }) { items[current].done = previous }
            actionError = "변경하지 못했어요"
        }
    }

    func delete(_ item: TodoDTO, using environment: AppEnvironment) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        actionError = nil
        let removed = items.remove(at: index)
        guard !isGuest else { return }
        do {
            try await environment.api.deleteTodo(id: item.id)
        } catch {
            items.insert(removed, at: min(index, items.count))
            actionError = "삭제하지 못했어요"
        }
    }

    static func guestSamples() -> [TodoDTO] {
        ["20분 산책하기", "물 6잔 마시기", "자기 전 5분 스트레칭"].map { guestItem(title: $0, source: .suggested) }
    }

    private static func guestItem(title: String, source: TodoDTO.Source) -> TodoDTO {
        TodoDTO(id: UUID().uuidString, title: title, source: source, done: false, doneAt: nil, createdAt: Date())
    }
}
