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
    private(set) var showsHoldHint = false

    var isPresented: Bool { mode != .idle }

    private var activationTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var didActivateByHold = false
    private var latestDragVector: CGSize = .zero

    private let holdDuration: Duration = .milliseconds(220)
    private let selectionInnerRadius: CGFloat = 30
    private let selectionOuterRadius: CGFloat = 224
    private let selectionHysteresis: CGFloat = 0.12

    let arcRadius: CGFloat = 122

    func configure(targets: [FamilyContact], questions: [String]) {
        self.targets = targets
        self.questions = questions
    }

    func pressBegan() {
        guard mode != .sticky else { return }
        hideHoldHint()
        Haptics.prepare()
        Haptics.press()
        didActivateByHold = false
        latestDragVector = .zero
        activationTask?.cancel()
        activationTask = Task { [weak self] in
            try? await Task.sleep(for: self?.holdDuration ?? .milliseconds(220))
            guard !Task.isCancelled else { return }
            self?.activateHold()
        }
    }

    func dragChanged(_ vector: CGSize) {
        latestDragVector = vector
        guard mode == .dragging else { return }
        updateFocus(for: vector)
    }

    func pressEnded(at vector: CGSize) -> FamilyContact? {
        activationTask?.cancel()
        activationTask = nil
        latestDragVector = vector
        if mode == .dragging {
            updateFocus(for: vector)
        }

        guard didActivateByHold else {
            showHoldHint()
            focusedIndex = nil
            return nil
        }

        let selected = focusedIndex.flatMap { targets.indices.contains($0) ? targets[$0] : nil }
        guard let selected else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                mode = .idle
            }
            focusedIndex = nil
            didActivateByHold = false
            latestDragVector = .zero
            Haptics.cancel()
            return nil
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        didActivateByHold = false
        latestDragVector = .zero
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
        hideHoldHint()
        if mode != .idle { Haptics.cancel() }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        didActivateByHold = false
        latestDragVector = .zero
    }

    func offset(for index: Int) -> CGSize {
        let radians = angle(for: index) * .pi / 180
        return CGSize(width: cos(radians) * arcRadius, height: sin(radians) * arcRadius)
    }

    func angleRange(for index: Int) -> ClosedRange<Double> {
        let count = max(targets.count, 1)
        let width = 180 / Double(count)
        let lowerBound = -180 + width * Double(index)
        return lowerBound...(lowerBound + width)
    }

    private func angle(for index: Int) -> Double {
        let range = angleRange(for: index)
        return (range.lowerBound + range.upperBound) / 2
    }

    private func activateHold() {
        guard !targets.isEmpty else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { mode = .sticky }
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { mode = .dragging }
        didActivateByHold = true
        updateFocus(for: latestDragVector)
        Haptics.open()
    }

    private func showHoldHint() {
        hintTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            showsHoldHint = true
        }
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                self?.showsHoldHint = false
            }
        }
    }

    private func hideHoldHint() {
        hintTask?.cancel()
        hintTask = nil
        if showsHoldHint {
            withAnimation(.easeOut(duration: 0.12)) { showsHoldHint = false }
        }
    }

    private func updateFocus(for vector: CGSize) {
        let nearest = selectionIndex(for: vector)

        if nearest != focusedIndex {
            focusedIndex = nearest
            if nearest == nil { Haptics.blur() } else { Haptics.focus() }
        }
    }

    private func selectionIndex(for vector: CGSize) -> Int? {
        let radius = hypot(vector.width, vector.height)
        guard vector.height < 0, selectionInnerRadius...selectionOuterRadius ~= radius else { return nil }

        guard let candidate = targets.indices.max(by: { lhs, rhs in
            selectionScore(for: vector, index: lhs) < selectionScore(for: vector, index: rhs)
        }) else { return nil }
        guard let focusedIndex, focusedIndex != candidate, targets.indices.contains(focusedIndex) else {
            return candidate
        }

        let candidateScore = selectionScore(for: vector, index: candidate)
        let focusedScore = selectionScore(for: vector, index: focusedIndex)
        let margin = radius * arcRadius * selectionHysteresis
        return candidateScore - focusedScore > margin ? candidate : focusedIndex
    }

    private func selectionScore(for vector: CGSize, index: Int) -> CGFloat {
        let targetOffset = offset(for: index)
        return vector.width * targetOffset.width + vector.height * targetOffset.height
    }
}
