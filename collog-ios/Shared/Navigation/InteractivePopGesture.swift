//
//  InteractivePopGesture.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI
import UIKit

extension View {
    func interactivePopGestureEnabled() -> some View {
        background(InteractivePopGestureEnabler().frame(width: 0, height: 0))
    }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopGestureViewController {
        InteractivePopGestureViewController()
    }

    func updateUIViewController(
        _ uiViewController: InteractivePopGestureViewController,
        context: Context
    ) {}
}

private final class InteractivePopGestureViewController: UIViewController {
    private var previousDelegate: UIGestureRecognizerDelegate?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
        previousDelegate = gesture.delegate
        gesture.delegate = nil
        gesture.isEnabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
        if gesture.delegate == nil {
            gesture.delegate = previousDelegate
        }
        previousDelegate = nil
    }
}
