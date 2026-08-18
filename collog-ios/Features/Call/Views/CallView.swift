//
//  CallView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallView: View {
    let peerName: String
    let phase: CallPhase
    let questions: [String]
    var notice: String?
    var onEnd: () -> Void

    @State private var connectedAt: Date?
    @State private var elapsed: TimeInterval = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, Spacing.x8)

            if let notice {
                Text(notice)
                    .caption_01_medium(.gray700)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x4)
            }

            ScrollView {
                questionList
                    .padding(.top, Spacing.x8)
                    .padding(.bottom, Spacing.x4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: Spacing.x4)

            endButton
                .padding(.bottom, Spacing.x8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray50)
        .onChange(of: phase, initial: true) { _, newPhase in
            if newPhase == .active, connectedAt == nil {
                connectedAt = Date()
            }
        }
        .onReceive(ticker) { _ in
            guard let connectedAt else { return }
            elapsed = Date().timeIntervalSince(connectedAt)
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.x4) {
            Circle()
                .fill(LinearGradient.avatar)
                .frame(width: 120, height: 120)

            VStack(spacing: Spacing.x2) {
                Text(peerName)
                    .headline_02(.gray900)

                if phase.showsTimer {
                    Text(CallDurationFormatter.text(for: elapsed))
                        .pretendard(.medium, 16, .gray700)
                        .monospacedDigit()
                } else {
                    Text(phase.statusText)
                        .pretendard(.medium, 16, .gray700)
                }
            }
        }
    }

    private var questionList: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            if !questions.isEmpty {
                Text("오늘의 건강 질문")
                    .caption_01_medium(.gray800)
                    .padding(.horizontal, Spacing.x1)
            }

            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                HStack(spacing: Spacing.x3) {
                    AssetPlaceholder(size: 13)
                        .frame(width: IconSize.medium, height: IconSize.medium)
                        .background(
                            Color.greenNormal,
                            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        )

                    Text(question)
                        .body_02_medium(.gray900)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .cardSurface(padding: Spacing.x3, cornerRadius: Radius.btnSmall)
            }
        }
        .padding(.horizontal, Spacing.x5)
    }

    private var endButton: some View {
        Button(action: onEnd) {
            AssetPlaceholder(size: 28)
                .frame(width: 72, height: 72)
                .background(Color.red500, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("통화 종료")
    }
}

#Preview {
    CallView(
        peerName: "어머니",
        phase: .active,
        questions: PreviewQuestion.samples.map(\.text)
    ) {}
}
