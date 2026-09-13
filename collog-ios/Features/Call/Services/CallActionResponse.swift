//
//  CallActionResponse.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import CallKit

@MainActor
final class CallActionResponse {
    private let isComplete: () -> Bool
    private let onFulfill: () -> Void
    private let onFail: () -> Void
    private let onFinished: () -> Void
    private var responded = false

    init(action: CXAction, onFinished: @escaping () -> Void = {}) {
        isComplete = { action.isComplete }
        onFulfill = { action.fulfill() }
        onFail = { action.fail() }
        self.onFinished = onFinished
    }

    init(isComplete: @escaping () -> Bool, fulfill: @escaping () -> Void, fail: @escaping () -> Void) {
        self.isComplete = isComplete
        onFulfill = fulfill
        onFail = fail
        onFinished = {}
    }

    func fulfill() {
        guard !responded else { return }
        responded = true
        defer { onFinished() }
        if !isComplete() { onFulfill() }
    }

    func fail() {
        guard !responded else { return }
        responded = true
        defer { onFinished() }
        if !isComplete() { onFail() }
    }

    func invalidate() {
        guard !responded else { return }
        responded = true
        onFinished()
    }
}
