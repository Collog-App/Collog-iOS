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
        HStack(spacing: 0) {
            Button(action: onProfileTap) {
                AssetPlaceholder(size: IconSize.medium)
                    .frame(width: IconSize.avatar, height: IconSize.avatar)
                    .background(Color.gray00, in: Circle())
                    .overlay(Circle().stroke(Color.greenNormal, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        AssetPlaceholder(size: 6, cornerRadius: 3)
                            .offset(x: 1, y: -1)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: Spacing.x3)

            HStack(spacing: 0) {
                iconButton(hasBadge: true, action: onNotificationTap)
                iconButton(hasBadge: false, action: onMenuTap)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Spacing.x5)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Color.gray00)
    }

    private func iconButton(hasBadge: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AssetPlaceholder(size: IconSize.medium)
                .frame(width: IconSize.button, height: IconSize.button, alignment: .trailing)
                .overlay(alignment: .topTrailing) {
                    if hasBadge {
                        AssetPlaceholder(size: 6, cornerRadius: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeTopBarView()
}
