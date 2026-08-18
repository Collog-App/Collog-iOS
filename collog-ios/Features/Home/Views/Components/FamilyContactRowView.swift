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
            HStack(spacing: 11) {
                Circle()
                    .fill(LinearGradient.avatar)
                    .frame(width: IconSize.contactAvatar, height: IconSize.contactAvatar)

                VStack(alignment: .leading, spacing: 6) {
                    Text(contact.name)
                        .pretendard(.medium, 18, .black)

                    HStack(spacing: 6) {
                        AssetPlaceholder(width: 9, height: 10)
                        Text(contact.line)
                            .body_02_medium(.gray700)
                    }
                }

                Spacer(minLength: Spacing.x2)

                Text(contact.lastCallText)
                    .body_02_medium(.gray700)
            }
            .padding(.horizontal, Spacing.x2)
            .frame(height: 75)
            .frame(maxWidth: .infinity)
            .background(Color.gray100, in: RoundedRectangle(cornerRadius: Radius.listItem, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: Spacing.x4) {
        ForEach(FamilyContact.samples) { contact in
            FamilyContactRowView(contact: contact)
        }
    }
    .padding()
}
