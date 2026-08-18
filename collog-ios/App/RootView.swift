//
//  RootView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct RootView: View {
    @State private var tabManager = TabManager()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tabManager.selectedTab {
                case .home:
                    HomeView()
                default:
                    ComingSoonView(title: tabManager.selectedTab.title)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBarView(selection: $tabManager.selectedTab)
        }
        .background(Color.gray00)
        .environment(tabManager)
    }
}

private struct ComingSoonView: View {
    let title: String

    var body: some View {
        Text(title)
            .subtitle_01(.gray600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray00)
    }
}

#Preview {
    RootView()
}
