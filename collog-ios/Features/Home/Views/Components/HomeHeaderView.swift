//
//  HomeHeaderView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HomeHeaderView: View {
    let contacts: [FamilyContact]
    let selected: FamilyContact
    let subtitle: String
    var onSelect: (FamilyContact) -> Void = { _ in }
    var onNotificationTap: () -> Void = {}
    var onMenuTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.x2) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                if contacts.count > 1 {
                    Menu {
                        ForEach(contacts) { contact in
                            Button(contact.name) { onSelect(contact) }
                        }
                    } label: {
                        nameLabel(showsChevron: true)
                    }
                } else {
                    nameLabel(showsChevron: false)
                }

                Text(subtitle)
                    .body_02_medium(.gray700)
            }

            Spacer(minLength: Spacing.x3)

            HStack(spacing: 0) {
                iconButton(symbol: "bell", hasBadge: true, action: onNotificationTap)
                iconButton(symbol: "line.3.horizontal", hasBadge: false, action: onMenuTap)
            }
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x2)
        .padding(.bottom, Spacing.x5)
    }

    private func nameLabel(showsChevron: Bool) -> some View {
        HStack(spacing: Spacing.x1) {
            Text(selected.name)
                .headline_02(.gray900)

            if showsChevron {
                Icon(name: "chevron.down", size: 18, weight: .semibold, color: .gray700)
            }
        }
    }

    private func iconButton(
        symbol: String,
        hasBadge: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Icon(name: symbol, color: .gray900)
                .frame(width: 40, height: 40)
                .overlay(alignment: .topTrailing) {
                    if hasBadge {
                        NotificationDot().offset(x: -4, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeHeaderView(
        contacts: FamilyContact.samples,
        selected: FamilyContact.samples[0],
        subtitle: "3일 전에 통화했어요"
    )
    .background(Color.gray50)
}
