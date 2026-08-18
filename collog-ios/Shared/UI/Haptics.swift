//
//  Haptics.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import UIKit

@MainActor
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        selection.prepare()
        light.prepare()
        medium.prepare()
        soft.prepare()
        rigid.prepare()
    }

    static func press() {
        light.impactOccurred(intensity: 0.55)
    }

    static func open() {
        medium.impactOccurred(intensity: 0.9)
        Task {
            try? await Task.sleep(for: .milliseconds(70))
            light.impactOccurred(intensity: 0.5)
        }
    }

    static func focus() {
        selection.selectionChanged()
    }

    static func blur() {
        soft.impactOccurred(intensity: 0.35)
    }

    static func commit() {
        rigid.impactOccurred(intensity: 1.0)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            notification.notificationOccurred(.success)
        }
    }

    static func cancel() {
        soft.impactOccurred(intensity: 0.6)
    }
}
