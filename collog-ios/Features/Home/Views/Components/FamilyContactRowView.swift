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

                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text(contact.name)
                        .body_01_semibold(.gray900)

                    HStack(spacing: Spacing.x1) {
                        AssetPlaceholder(width: 9, height: 9)
                        Text(contact.line)
                            .caption_01_medium(.gray800)
                    }
                }

                Spacer(minLength: Spacing.x2)

                Text(contact.lastCallText)
                    .caption_01_medium(.gray700)
            }
            .cardSurface()
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Spacing.x3) {
        ForEach(FamilyContact.samples) { contact in
            FamilyContactRowView(contact: contact)
        }
    }
    .padding()
    .background(Color.gray50)
}
