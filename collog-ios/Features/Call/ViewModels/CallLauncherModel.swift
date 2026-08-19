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
    private var latestTranslation: CGSize = .zero

    private let holdDuration: Duration = .milliseconds(220)
    private let selectionInnerRadius: CGFloat = 30
    private let selectionOuterRadius: CGFloat = 194

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
        latestTranslation = .zero
        activationTask?.cancel()
        activationTask = Task { [weak self] in
            try? await Task.sleep(for: self?.holdDuration ?? .milliseconds(220))
            guard !Task.isCancelled else { return }
            self?.activateHold()
        }
    }

    func dragChanged(_ translation: CGSize) {
        latestTranslation = translation
        guard mode == .dragging else { return }
        updateFocus(for: translation)
    }

    func pressEnded() -> FamilyContact? {
        activationTask?.cancel()
        activationTask = nil

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
            latestTranslation = .zero
            Haptics.cancel()
            return nil
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { mode = .idle }
        focusedIndex = nil
        didActivateByHold = false
        latestTranslation = .zero
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
        latestTranslation = .zero
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
        updateFocus(for: latestTranslation)
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

    private func updateFocus(for translation: CGSize) {
        let nearest = selectionIndex(for: translation)

        if nearest != focusedIndex {
            focusedIndex = nearest
            if nearest == nil { Haptics.blur() } else { Haptics.focus() }
        }
    }

    private func selectionIndex(for translation: CGSize) -> Int? {
        let radius = hypot(translation.width, translation.height)
        guard translation.height < 0, selectionInnerRadius...selectionOuterRadius ~= radius else { return nil }

        return targets.indices.max { lhs, rhs in
            selectionScore(for: translation, index: lhs) < selectionScore(for: translation, index: rhs)
        }
    }

    private func selectionScore(for translation: CGSize, index: Int) -> CGFloat {
        let targetOffset = offset(for: index)
        return translation.width * targetOffset.width + translation.height * targetOffset.height
    }
}
