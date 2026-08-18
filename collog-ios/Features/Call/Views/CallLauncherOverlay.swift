//
//  CallLauncherOverlay.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct CallLauncherOverlay: View {
    let model: CallLauncherModel
    var anchorInset: CGFloat
    var notice: String?
    var onSelect: (Int) -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ZStack {
                questionStack
                targetFan
            }
            .padding(.bottom, anchorInset)
        }
        .transition(.opacity)
    }

    private var questionStack: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            if let notice {
                hint(notice)
            }

            if model.questions.isEmpty {
                hint("오늘의 질문이 아직 없어요")
            } else {
                Text("이 질문으로 시작해보세요")
                    .caption_02_medium(.gray700)
                    .padding(.leading, Spacing.x2)

                ForEach(Array(model.questions.prefix(3).enumerated()), id: \.offset) { index, question in
                    questionChip(question, index: index)
                }
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
        .offset(y: -(model.arcRadius + 130))
        .allowsHitTesting(false)
    }

    private func questionChip(_ text: String, index: Int) -> some View {
        HStack(spacing: Spacing.x2) {
            Circle()
                .fill(Color.greenNormal)
                .frame(width: 8, height: 8)

            Text(text)
                .body_03_medium(.gray900)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Spacing.x3)
        .padding(.vertical, Spacing.x2)
        .background(Color.gray00, in: Capsule())
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(
            .spring(response: 0.34, dampingFraction: 0.78).delay(Double(index) * 0.05),
            value: model.isPresented
        )
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .body_03_medium(.gray800)
            .padding(.horizontal, Spacing.x4)
            .padding(.vertical, Spacing.x3)
            .background(Color.gray00, in: Capsule())
    }

    private var targetFan: some View {
        ZStack {
            ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, contact in
                targetBubble(contact, index: index)
            }
        }
    }

    private func targetBubble(_ contact: FamilyContact, index: Int) -> some View {
        let isFocused = model.focusedIndex == index

        return VStack(spacing: Spacing.x1) {
            Circle()
                .fill(LinearGradient.avatar)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(Color.greenNormal, lineWidth: isFocused ? 3 : 0)
                )
                .shadow(color: .black.opacity(isFocused ? 0.16 : 0.08), radius: isFocused ? 16 : 8, y: 4)
                .scaleEffect(isFocused ? 1.16 : 1)

            Text(contact.name)
                .caption_01_semibold(isFocused ? .gray900 : .gray800)
        }
        .offset(model.offset(for: index))
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
        .animation(
            .spring(response: 0.36, dampingFraction: 0.74).delay(Double(index) * 0.04),
            value: model.isPresented
        )
        .contentShape(Circle())
        .onTapGesture { onSelect(index) }
        .allowsHitTesting(model.mode == .sticky)
    }
}

#Preview {
    let model = CallLauncherModel()
    model.configure(
        targets: FamilyContact.samples,
        questions: PreviewQuestion.samples.map(\.text)
    )

    return ZStack {
        Color.gray50.ignoresSafeArea()
        CallLauncherOverlay(model: model, anchorInset: 46, onSelect: { _ in }, onDismiss: {})
    }
}
