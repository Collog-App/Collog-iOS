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

        let ink = UIColor(red: 0x2A / 255, green: 0x30 / 255, blue: 0x38 / 255, alpha: 1)
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "Pretendard-Bold", size: 28) ?? .systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: ink,
            .kern: -0.7
        ]
        appearance.titleTextAttributes = [
            .font: UIFont(name: "Pretendard-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: ink,
            .kern: -0.42
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
