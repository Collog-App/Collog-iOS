//
//  ChangeSignalCardView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct ChangeSignalCardView: View {
    let signals: [ChangeSignalItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("변화 신호")
                .caption_01_medium(.gray800)

            if signals.isEmpty {
                Text("이번 주에는 눈에 띄는 변화가 없었어요.")
                    .body_02_medium(.gray800)
            } else {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                        if index > 0 {
                            DividerLine()
                        }
                        row(for: signal)
                    }
                }
            }
        }
        .cardSurface()
    }

    private func row(for signal: ChangeSignalItem) -> some View {
        HStack(alignment: .top, spacing: Spacing.x3) {
            Circle()
                .fill(signal.tone == .watch ? Color.orange600 : Color.greenNormal)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Spacing.x1) {
                HStack(spacing: Spacing.x2) {
                    Text(signal.metricName)
                        .body_01_semibold(.gray900)

                    if signal.isPromoted {
                        BadgeView(
                            label: "지속",
                            foregroundColor: .orange600,
                            backgroundColor: .orangeLight
                        )
                    }
                }

                Text(signal.summary)
                    .body_02_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ChangeSignalCardView(signals: WeeklyReport.sample.changeSignals)
        .padding()
        .background(Color.gray50)
}
