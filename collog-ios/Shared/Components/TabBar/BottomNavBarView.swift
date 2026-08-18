//
//  BottomNavBarView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct BottomNavBarView: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 2) {
                        AssetPlaceholder(size: IconSize.medium)
                        Text(tab.title)
                            .caption_01_medium(selection == tab ? .greenNormal : .gray600)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x2)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.gray00)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray200)
                .frame(height: 1)
        }
    }
}

#Preview {
    @Previewable @State var selection = MainTab.home

    BottomNavBarView(selection: $selection)
}
