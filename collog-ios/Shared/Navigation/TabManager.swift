//
//  TabManager.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

@Observable
final class TabManager {
    var selectedTab: MainTab = TabManager.launchTab

    private static var launchTab: MainTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"),
           let tab = MainTab(rawValue: raw) {
            return tab
        }
        #endif
        return .home
    }
}
