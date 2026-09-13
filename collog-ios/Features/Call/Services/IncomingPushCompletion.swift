//
//  IncomingPushCompletion.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import Foundation

@MainActor
final class IncomingPushCompletion {
    private var completion: (() -> Void)?

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func finish() {
        let callback = completion
        completion = nil
        callback?()
    }
}
