//
//  OnboardingView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let symbols: [String]
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var index = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "통화 한 번이 건강 기록이 됩니다",
            body: "부모님과의 통화에서 평소와 달라진 점을 차분하게 확인하세요.\n"
                + "진단이 아닌, 우리 가족만의 기록입니다.",
            symbols: ["phone.fill", "waveform", "chart.line.uptrend.xyaxis"]
        ),
        OnboardingPage(
            title: "오늘의 질문으로 시작해요",
            body: "등록한 질환과 지난 통화를 바탕으로 오늘 여쭤볼 질문을 준비해드려요.",
            symbols: ["text.bubble.fill", "sparkles", "questionmark.bubble.fill"]
        ),
        OnboardingPage(
            title: "원본 음성은 남기지 않아요",
            body: "통화 음성은 분석 직후 바로 지우고, 정리된 기록과 변화값만 보관해요.",
            symbols: ["waveform", "trash.fill", "checkmark.shield.fill"]
        )
    ]

    var body: some View {
        VStack(spacing: Spacing.x6) {
            indicator
                .padding(.top, Spacing.x8)

            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { offset, item in
                    page(for: item)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button(action: advance) {
                Text(index == pages.count - 1 ? "시작하기" : "다음")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Color.greenNormal,
                        in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.x5)
            .padding(.bottom, Spacing.x8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray50)
    }

    private var indicator: some View {
        HStack(spacing: Spacing.x2) {
            ForEach(pages.indices, id: \.self) { position in
                Capsule()
                    .fill(position == index ? Color.gray900 : Color.gray400)
                    .frame(width: position == index ? 22 : 10, height: 10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
    }

    private func page(for page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x6) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text(page.title)
                    .headline_02(.gray900)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .body_01_regular(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }

            symbolRow(for: page)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.x5)
    }

    private func symbolRow(for page: OnboardingPage) -> some View {
        HStack(spacing: Spacing.x8) {
            ForEach(Array(page.symbols.enumerated()), id: \.element) { index, symbol in
                Image(systemName: symbol)
                    .font(.system(size: symbolSize(at: index), weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(symbolColor(at: index))
                    .frame(width: 72, height: 96)
                    .offset(y: index == 1 ? -8 : 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 212)
    }

    private func symbolSize(at index: Int) -> CGFloat {
        index == 1 ? 58 : 44
    }

    private func symbolColor(at index: Int) -> Color {
        index == 1 ? .greenNormal : .gray700
    }

    private func advance() {
        if index < pages.count - 1 {
            withAnimation { index += 1 }
        } else {
            onFinish()
        }
    }
}

#Preview {
    OnboardingView {}
}
