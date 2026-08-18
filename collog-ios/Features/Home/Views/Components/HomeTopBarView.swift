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
                        NotificationDot().offset(x: -3, y: 3)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: Spacing.x3)

            iconButton(symbol: "bell", hasBadge: true, action: onNotificationTap)
            iconButton(symbol: "line.3.horizontal", hasBadge: false, action: onMenuTap)
        }
        .padding(.horizontal, Spacing.x5)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
    }

    private func iconButton(
        symbol: String,
        hasBadge: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Icon(name: symbol, color: .gray900)
                .frame(width: 36, height: 36)
                .overlay(alignment: .topTrailing) {
                    if hasBadge {
                        NotificationDot().offset(x: -2, y: 2)
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
