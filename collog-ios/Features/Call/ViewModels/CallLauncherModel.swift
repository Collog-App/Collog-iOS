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

    let arcRadius: CGFloat = 122
    private let startAngle = -122.0
    private let endAngle = -58.0

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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                mode = mode == .sticky ? .idle : .sticky
            }
            focusedIndex = nil
            return nil
        }

        let selected = focusedIndex.flatMap { targets.indices.contains($0) ? targets[$0] : nil }
        guard let selected else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                mode = .sticky
            }
            focusedIndex = nil
            didActivateByHold = false
            Haptics.blur()
            return nil
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        didActivateByHold = false
        Haptics.commit()
        return selected
    }

    func select(_ index: Int) -> FamilyContact? {
        guard targets.indices.contains(index) else { return nil }
        Haptics.commit()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        return targets[index]
    }

    func dismiss() {
        activationTask?.cancel()
        activationTask = nil
        if mode != .idle { Haptics.cancel() }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        didActivateByHold = false
    }

    func offset(for index: Int) -> CGSize {
        let radians = angle(for: index) * .pi / 180
        return CGSize(width: cos(radians) * arcRadius, height: sin(radians) * arcRadius)
    }

    func angleRange(for index: Int) -> ClosedRange<Double> {
        let count = max(targets.count, 1)
        let step = count == 1 ? 56 : abs(endAngle - startAngle) / Double(count - 1)
        let halfWidth = min(step / 2, 32)
        let center = angle(for: index)
        return (center - halfWidth)...(center + halfWidth)
    }

    private func angle(for index: Int) -> Double {
        let count = max(targets.count, 1)
        let ratio = count == 1 ? 0.5 : Double(index) / Double(count - 1)
        return startAngle + (endAngle - startAngle) * ratio
    }

    private func activateHold() {
        guard !targets.isEmpty else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { mode = .sticky }
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { mode = .dragging }
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
