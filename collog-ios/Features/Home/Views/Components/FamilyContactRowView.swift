//
//  FamilyContactRowView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct FamilyContactRowView: View {
    let contact: FamilyContact
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.x3) {
                Circle()
                    .fill(LinearGradient.avatar)
                    .frame(width: IconSize.contactAvatar, height: IconSize.contactAvatar)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .body_01_semibold(.gray900)
                    Text(contact.lastCallText)
                        .caption_01_medium(.gray700)
                }

                Spacer(minLength: Spacing.x2)

                AssetPlaceholder(size: IconSize.medium)
                    .frame(width: 36, height: 36)
            }
            .cardSurface(padding: Spacing.x3)
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Spacing.x2) {
        ForEach(FamilyContact.samples) { contact in
            FamilyContactRowView(contact: contact)
        }
    }
    .padding()
    .background(Color.gray50)
}
