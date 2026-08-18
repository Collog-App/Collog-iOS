//
//  WeekNavigatorView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct WeekNavigatorView: View {
    let title: String
    let rangeText: String
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.x2) {
            Button(action: onPrevious) {
                Icon(name: "chevron.left", size: IconSize.medium, color: .gray800)
            }
            .buttonStyle(.plain)

            Spacer(minLength: Spacing.x2)

            VStack(spacing: 0) {
                Text(title)
                    .body_01_semibold(.gray900)
                Text(rangeText)
                    .body_03_medium(.gray800)
            }

            Spacer(minLength: Spacing.x2)

            Button(action: onNext) {
                Icon(name: "chevron.right", size: IconSize.medium, color: .gray800)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.x4)
        .padding(.vertical, Spacing.x2)
        .overlay(alignment: .bottom) {
            DividerLine()
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x2)
    }
}

#Preview {
    WeekNavigatorView(title: "8월 3주", rangeText: "8/10 ~ 8/16")
        .background(Color.gray50)
}
