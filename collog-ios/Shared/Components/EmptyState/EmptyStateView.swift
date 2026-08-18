//
//  EmptyStateView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.x3) {
            Icon(name: symbol, size: 34, weight: .regular, color: .gray500)

            VStack(spacing: Spacing.x1) {
                Text(title)
                    .body_01_semibold(.gray800)
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .body_03_medium(.gray700)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .body_02_semibold(.greenDark)
                        .padding(.horizontal, Spacing.x4)
                        .frame(height: 40)
                        .background(Color.greenLight, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.x1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.x5)
        .padding(.vertical, Spacing.x8)
    }
}

#Preview {
    EmptyStateView(
        symbol: "phone.badge.waveform",
        title: "이번 주에는 분석된 통화가 없어요",
        message: "가족과 통화하면 이곳에 기록이 쌓여요."
    )
    .background(Color.gray50)
}
