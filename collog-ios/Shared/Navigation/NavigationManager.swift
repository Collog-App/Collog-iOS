//
//  NavigationManager.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class NavigationManager {
    var path = NavigationPath()

    func push<T: Hashable>(_ value: T) {
        path.append(value)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}

private struct NavigationManagerKey: EnvironmentKey {
    static let defaultValue = NavigationManager()
}

extension EnvironmentValues {
    var navigationManager: NavigationManager {
        get { self[NavigationManagerKey.self] }
        set { self[NavigationManagerKey.self] = newValue }
    }
}
