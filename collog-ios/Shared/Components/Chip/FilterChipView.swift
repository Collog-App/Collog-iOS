//
//  FilterChipView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct FilterChipView: View {
    let label: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.x1) {
                Text(label)
                    .body_02_medium(.gray800)
                AssetPlaceholder(size: IconSize.small)
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.vertical, 6)
            .background(Color.gray200, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .stroke(Color.gray300, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterChipView(label: "어머니")
        .padding()
        .background(Color.gray50)
}
