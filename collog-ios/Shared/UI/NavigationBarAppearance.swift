//
//  NavigationBarAppearance.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import UIKit

enum NavigationBarAppearance {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0xFA / 255, green: 0xFB / 255, blue: 0xFC / 255, alpha: 1)
        appearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
