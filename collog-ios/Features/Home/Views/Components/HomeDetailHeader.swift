//
//  HomeDetailHeader.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HomeDetailHeader: View {
    @Environment(\.dismiss) private var dismiss

    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Icon(name: "chevron.left", size: 20, color: .gray900)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Spacer(minLength: Spacing.x2)

            Text(title)
                .body_01_semibold(.gray900)

            Spacer(minLength: Spacing.x2)

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, Spacing.x3)
        .frame(height: 52)
        .background(Color.gray50)
    }
}

#Preview {
    HomeDetailHeader(title: "가족 건강")
}
