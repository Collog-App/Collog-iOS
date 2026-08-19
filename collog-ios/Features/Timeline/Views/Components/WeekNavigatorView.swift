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
    var canGoForward = true
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        HStack(spacing: Spacing.x2) {
            arrowButton(symbol: "chevron.left", enabled: true, action: onPrevious)

            Spacer(minLength: Spacing.x2)

            VStack(spacing: 0) {
                Text(title)
                    .body_01_semibold(.gray900)
                Text(rangeText)
                    .body_03_medium(.gray800)
            }

            Spacer(minLength: Spacing.x2)

            arrowButton(symbol: "chevron.right", enabled: canGoForward, action: onNext)
        }
        .padding(.horizontal, Spacing.x2)
        .overlay(alignment: .bottom) {
            DividerLine()
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x2)
    }

    private func arrowButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Icon(name: symbol, size: IconSize.medium, color: enabled ? .gray800 : .gray400)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct TimelineWeekHeader: View {
    let title: String
    let rangeText: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
            Text(title)
                .body_01_semibold(.gray900)

            Text(rangeText)
                .body_03_medium(.gray700)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x4)
        .frame(maxWidth: .infinity)
        .background(Color.gray50)
        .overlay(alignment: .bottom) {
            DividerLine()
        }
    }
}

#Preview {
    WeekNavigatorView(title: "8월 3주", rangeText: "8/10 ~ 8/16")
        .background(Color.gray50)
}
