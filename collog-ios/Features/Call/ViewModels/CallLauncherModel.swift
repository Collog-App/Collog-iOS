//
//  CallLauncherModel.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class CallLauncherModel {
    enum Mode {
        case idle
        case dragging
        case sticky
    }

    private(set) var mode: Mode = .idle
    private(set) var focusedIndex: Int?
    private(set) var targets: [FamilyContact] = []
    private(set) var questions: [String] = []

    var isPresented: Bool { mode != .idle }

    private var activationTask: Task<Void, Never>?
    private var didActivateByHold = false

    private let holdDuration: Duration = .milliseconds(280)
    private let hitRadius: CGFloat = 58
    private let arcRadius: CGFloat = 118

    func configure(targets: [FamilyContact], questions: [String]) {
        self.targets = targets
        self.questions = questions
    }

    func pressBegan() {
        guard mode != .sticky else { return }
        Haptics.prepare()
        Haptics.press()
        didActivateByHold = false
        activationTask?.cancel()
        activationTask = Task { [weak self] in
            try? await Task.sleep(for: self?.holdDuration ?? .milliseconds(280))
            guard !Task.isCancelled else { return }
            self?.activateHold()
        }
    }

    func dragChanged(_ translation: CGSize) {
        guard mode == .dragging else { return }
        updateFocus(for: translation)
    }

    func pressEnded() -> FamilyContact? {
        activationTask?.cancel()
        activationTask = nil

        guard didActivateByHold else {
            mode = mode == .sticky ? .idle : .sticky
            focusedIndex = nil
            return nil
        }

        let selected = focusedIndex.flatMap { targets.indices.contains($0) ? targets[$0] : nil }
        mode = .idle
        focusedIndex = nil
        didActivateByHold = false

        if selected != nil {
            Haptics.commit()
        } else {
            Haptics.cancel()
        }
        return selected
    }

    func select(_ index: Int) -> FamilyContact? {
        guard targets.indices.contains(index) else { return nil }
        Haptics.commit()
        mode = .idle
        focusedIndex = nil
        return targets[index]
    }

    func dismiss() {
        activationTask?.cancel()
        activationTask = nil
        if mode != .idle { Haptics.cancel() }
        mode = .idle
        focusedIndex = nil
        didActivateByHold = false
    }

    func offset(for index: Int) -> CGSize {
        let count = max(targets.count, 1)
        let startAngle = -148.0
        let endAngle = -32.0
        let ratio = count == 1 ? 0.5 : Double(index) / Double(count - 1)
        let radians = (startAngle + (endAngle - startAngle) * ratio) * .pi / 180
        return CGSize(width: cos(radians) * arcRadius, height: sin(radians) * arcRadius)
    }

    private func activateHold() {
        guard !targets.isEmpty else {
            mode = .sticky
            return
        }
        mode = .dragging
        didActivateByHold = true
        Haptics.open()
    }

    private func updateFocus(for translation: CGSize) {
        let point = CGPoint(x: translation.width, y: translation.height)
        let nearest = targets.indices
            .map { ($0, distance(from: point, to: offset(for: $0))) }
            .filter { $0.1 <= hitRadius }
            .min { $0.1 < $1.1 }?
            .0

        if nearest != focusedIndex {
            focusedIndex = nearest
            if nearest == nil { Haptics.blur() } else { Haptics.focus() }
        }
    }

    private func distance(from point: CGPoint, to offset: CGSize) -> CGFloat {
        let dx = point.x - offset.width
        let dy = point.y - offset.height
        return (dx * dx + dy * dy).squareRoot()
    }
}
