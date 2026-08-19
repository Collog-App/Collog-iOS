//
//  OnboardingView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

private struct OnboardingFeature: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
}

struct OnboardingView: View {
    var onFinish: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.x3),
        GridItem(.flexible(), spacing: Spacing.x3)
    ]

    private let features = [
        OnboardingFeature(
            id: "call",
            symbol: "phone.fill",
            title: "가족 통화",
            detail: "어머니, 아버지와 바로 연결"
        ),
        OnboardingFeature(
            id: "questions",
            symbol: "questionmark.bubble.fill",
            title: "오늘의 질문",
            detail: "다음 대화를 편하게 준비"
        ),
        OnboardingFeature(
            id: "report",
            symbol: "chart.line.uptrend.xyaxis",
            title: "주간 리포트",
            detail: "통화에서 찾은 변화를 확인"
        ),
        OnboardingFeature(
            id: "timeline",
            symbol: "clock.arrow.circlepath",
            title: "타임라인",
            detail: "지난 기록을 주차별로 모아보기"
        )
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.x6) {
                        brand
                        title
                        featureGrid
                    }
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x5)
                    .padding(.bottom, Spacing.x4)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                startButton
                    .padding(.horizontal, Spacing.x5)
                    .padding(.top, Spacing.x3)
                    .padding(.bottom, Spacing.x5)
            }
        }
        .preferredColorScheme(.light)
    }

    private var background: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0), SIMD2<Float>(1, 0),
                SIMD2<Float>(0, 0.5), SIMD2<Float>(0.52, 0.46), SIMD2<Float>(1, 0.5),
                SIMD2<Float>(0, 1), SIMD2<Float>(0.48, 1), SIMD2<Float>(1, 1)
            ],
            colors: [
                Color(hex: 0xFAFBFC), Color(hex: 0xEAF5EF), Color(hex: 0xF7F5F1),
                Color(hex: 0xF2F3F1), Color(hex: 0xDDF3E8), Color(hex: 0xF4F5F6),
                Color(hex: 0xFAFBFC), Color(hex: 0xE8F4EE), Color(hex: 0xF7F8F9)
            ]
        )
        .overlay(Color.gray00.opacity(0.18))
        .ignoresSafeArea()
    }

    private var brand: some View {
        Text("콜록")
            .body_02_semibold(.gray900)
    }

    private var title: some View {
        Text("가족의 목소리와 건강을\n함께 기억하세요")
            .pretendard(.semiBold, 26, .gray900)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var featureGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.x3) {
            ForEach(features) { feature in
                featureCard(feature)
            }
        }
    }

    private func featureCard(_ feature: OnboardingFeature) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: feature.symbol)
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.greenDark)

            Spacer(minLength: Spacing.x5)

            Text(feature.title)
                .body_02_semibold(.gray900)

            Text(feature.detail)
                .caption_01_regular(.gray700)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(
            Color.gray00.opacity(0.52),
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gray00.opacity(0.78), lineWidth: 1)
        }
    }

    private var startButton: some View {
        Button(action: onFinish) {
            Text("시작하기")
                .body_01_semibold(.gray00)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.greenNormal, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView {}
}
