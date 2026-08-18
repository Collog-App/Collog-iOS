//
//  NavigationStore.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

@Observable
final class NavigationStore {
    private var managers: [MainTab: NavigationManager] = [:]

    func manager(for tab: MainTab) -> NavigationManager {
        if let existing = managers[tab] { return existing }
        let created = NavigationManager()
        managers[tab] = created
        return created
    }

    func popToRoot(_ tab: MainTab) {
        managers[tab]?.popToRoot()
    }
}
