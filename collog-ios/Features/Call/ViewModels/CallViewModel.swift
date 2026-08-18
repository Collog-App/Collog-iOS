//
//  CallViewModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class CallViewModel {
    let contact: FamilyContact
    let questions: [PreviewQuestion]

    private(set) var phase: CallPhase = .connecting
    private(set) var elapsed: TimeInterval = 0

    private var connectedAt: Date?

    init(contact: FamilyContact, questions: [PreviewQuestion]) {
        self.contact = contact
        self.questions = questions
    }

    var durationText: String { CallDurationFormatter.text(for: elapsed) }

    func markConnected() {
        guard phase != .active else { return }
        connectedAt = Date()
        phase = .active
    }

    func markRinging() {
        guard phase == .connecting else { return }
        phase = .ringing
    }

    func tick() {
        guard phase == .active, let connectedAt else { return }
        elapsed = Date().timeIntervalSince(connectedAt)
    }

    func end() {
        phase = .ended
    }
}
