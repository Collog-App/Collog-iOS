//
//  IncomingCallActionsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/14/26.
//

import SwiftUI

struct IncomingCallActionsView: View {
    let canAnswer: Bool
    let isAnswering: Bool
    let onAnswer: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: Spacing.x8) {
            actionButton("거절", symbol: "phone.down.fill", color: .red500, action: onDecline)
                .disabled(isAnswering)
            actionButton(
                isAnswering ? "받는 중" : "받기", symbol: "phone.fill",
                color: .greenNormal, action: onAnswer
            )
            .disabled(!canAnswer)
            .opacity(canAnswer || isAnswering ? 1 : 0.45)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(
        _ title: String, symbol: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.x2) {
                Icon(name: symbol, size: 30, weight: .semibold, color: .gray00)
                    .frame(width: 72, height: 72)
                    .background(color, in: Circle())
                Text(title)
                    .body_03_medium(.gray00)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "거절" ? "수신 전화 거절" : "수신 전화 받기")
    }
}
