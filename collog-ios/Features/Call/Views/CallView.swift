//
//  CallView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Combine
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
                    .caption_01_medium(.gray500)
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
        .background(callBackground)
        .preferredColorScheme(.dark)
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
                .fill(Color.gray00.opacity(0.1))
                .frame(width: 120, height: 120)
                .overlay {
                    Text(String(peerName.prefix(1)))
                        .pretendard(.semiBold, 40, .gray00)
                }

            VStack(spacing: Spacing.x2) {
                Text(peerName)
                    .headline_02(.gray00)

                if phase.showsTimer {
                    Text(CallDurationFormatter.text(for: elapsed))
                        .pretendard(.medium, 16, .gray400)
                        .monospacedDigit()
                } else {
                    Text(phase.statusText)
                        .pretendard(.medium, 16, .gray400)
                }
            }
        }
    }

    private var questionList: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            if !questions.isEmpty {
                Text("오늘의 질문")
                    .caption_01_medium(.gray500)
                    .padding(.horizontal, Spacing.x1)
            }

            ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                HStack(spacing: Spacing.x3) {
                    Text(String(format: "%02d", index + 1))
                        .caption_01_semibold(.green400)

                    Text(question)
                        .body_02_medium(.gray00)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(Spacing.x3)
                .background(
                    Color.gray00.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        .stroke(Color.gray00.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .padding(.horizontal, Spacing.x5)
    }

    private var endButton: some View {
        Button(action: onEnd) {
            Icon(name: "phone.down.fill", size: 30, weight: .semibold, color: .gray00)
                .frame(width: 72, height: 72)
                .background(Color.red500, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("통화 종료")
    }

    private var callBackground: some View {
        LinearGradient(
            colors: [Color(hex: 0x171A20), Color(hex: 0x07080A)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    CallView(
        peerName: "어머니",
        phase: .active,
        questions: PreviewQuestion.samples.map(\.text)
    ) {}
}
