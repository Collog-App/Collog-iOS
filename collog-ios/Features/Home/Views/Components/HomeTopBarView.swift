//
//  HomeTopBarView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct HomeTopBarView: View {
    var onProfileTap: () -> Void = {}
    var onNotificationTap: () -> Void = {}
    var onMenuTap: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.x2) {
            Button(action: onProfileTap) {
                Circle()
                    .fill(LinearGradient.avatar)
                    .frame(width: IconSize.avatar, height: IconSize.avatar)
                    .overlay(alignment: .topTrailing) {
                        AssetPlaceholder(size: 6, cornerRadius: 3)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: Spacing.x3)

            iconButton(hasBadge: true, action: onNotificationTap)
            iconButton(hasBadge: false, action: onMenuTap)
        }
        .padding(.horizontal, Spacing.x5)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
    }

    private func iconButton(hasBadge: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AssetPlaceholder(size: IconSize.medium)
                .frame(width: 36, height: 36)
                .overlay(alignment: .topTrailing) {
                    if hasBadge {
                        AssetPlaceholder(size: 6, cornerRadius: 3)
                            .offset(x: -2, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeTopBarView()
        .background(Color.gray50)
}
