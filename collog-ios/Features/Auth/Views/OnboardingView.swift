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
        .preferredColorScheme(.dark)
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
                Color(hex: 0x1E2425), Color(hex: 0x4B514A), Color(hex: 0x17191D),
                Color(hex: 0x302E2B), Color(hex: 0x183A2D), Color(hex: 0x27292D),
                Color(hex: 0x151719), Color(hex: 0x33463E), Color(hex: 0x101113)
            ]
        )
        .overlay(Color.black.opacity(0.14))
        .ignoresSafeArea()
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("콜록")
                .body_02_semibold(.gray00)

            Rectangle()
                .fill(Color.gray00.opacity(0.18))
                .frame(height: 1)
        }
    }

    private var title: some View {
        Text("가족과의 통화를\n더 오래 기억하세요")
            .pretendard(.medium, 34, .gray00)
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
                .foregroundStyle(Color.gray00)

            Spacer(minLength: Spacing.x5)

            Text(feature.title)
                .body_01_semibold(.gray00)

            Text(feature.detail)
                .caption_01_medium(.gray400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.gray00.opacity(0.22), lineWidth: 1)
        }
    }

    private var startButton: some View {
        Button(action: onFinish) {
            Text("시작하기")
                .body_01_semibold(.gray900)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.gray00, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView {}
}
