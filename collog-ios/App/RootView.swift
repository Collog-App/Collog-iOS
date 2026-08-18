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
                case .report:
                    TimelineView(initialTabIndex: 0)
                case .timeline:
                    TimelineView(initialTabIndex: 1)
                default:
                    ComingSoonView(title: tabManager.selectedTab.title)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBarView(selection: $tabManager.selectedTab)
        }
        .background(Color.gray50)
        .environment(tabManager)
    }
}

private struct ComingSoonView: View {
    let title: String

    var body: some View {
        Text(title)
            .subtitle_01(.gray600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray50)
    }
}

#Preview {
    RootView()
}
