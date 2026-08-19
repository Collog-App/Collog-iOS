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

            ambientGradient
            topNotice

            RadialGradient(
                colors: [Color.greenNormal.opacity(0.14), Color.greenNormal.opacity(0)],
                center: .center,
                startRadius: 8,
                endRadius: 300
            )
            .frame(width: 600, height: 600)
            .offset(y: 300 - anchorInset)
            .allowsHitTesting(false)

            ZStack {
                questionStack
                targetFan
            }
            .frame(width: 0, height: 0)
            .padding(.bottom, anchorInset)
        }
        .transition(.opacity)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: model.isPresented)
    }

    private var ambientGradient: some View {
        ZStack {
            Circle()
                .fill(Color.greenNormal.opacity(0.14))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: -120, y: 160)

            Circle()
                .fill(Color.greenLightActive.opacity(0.24))
                .frame(width: 300, height: 300)
                .blur(radius: 64)
                .offset(x: 140, y: -100)
        }
        .phaseAnimator([false, true]) { content, phase in
            content
                .rotationEffect(.degrees(phase ? 7 : -5))
                .scaleEffect(phase ? 1.06 : 0.96)
        } animation: { _ in
            .easeInOut(duration: 3.8)
        }
        .allowsHitTesting(false)
    }

    private var questionStack: some View {
        VStack(alignment: .center, spacing: 0) {
            if model.questions.isEmpty {
                hint("오늘의 질문이 아직 없어요")
            } else {
                Text("이 질문으로 시작해보세요")
                    .caption_01_medium(.gray700)
                    .padding(.leading, Spacing.x2)

                VStack(spacing: Spacing.x2) {
                    ForEach(Array(model.questions.prefix(3).enumerated()), id: \.offset) { index, question in
                        questionChip(question, index: index)
                    }
                }
                .padding(.top, Spacing.x4)
            }
        }
        .frame(width: 300)
        .offset(y: -(model.arcRadius + 245))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var topNotice: some View {
        if let notice {
            VStack(spacing: 0) {
                hint(notice)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, Spacing.x4)
            .allowsHitTesting(false)
        }
    }

    private func questionChip(_ text: String, index: Int) -> some View {
        HStack(spacing: Spacing.x2) {
            Text(String(format: "%02d", index + 1))
                .caption_01_semibold(.green700)

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
        .phaseAnimator([false, true]) { content, phase in
            content.offset(y: phase ? -3 : 3)
        } animation: { _ in
            .easeInOut(duration: 2.7 + Double(index) * 0.32)
        }
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
            fanZones

            ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, contact in
                targetBubble(contact, index: index)
            }
        }
    }

    private var fanZones: some View {
        ZStack {
            ForEach(model.targets.indices, id: \.self) { index in
                let angleRange = model.angleRange(for: index)
                let isFocused = model.focusedIndex == index

                FanSector(
                    innerRadius: 34,
                    outerRadius: 178,
                    startAngle: angleRange.lowerBound,
                    endAngle: angleRange.upperBound
                )
                .fill(isFocused ? Color.greenLightActive.opacity(0.28) : Color.gray00.opacity(0.16))
                .overlay {
                    FanSector(
                        innerRadius: 34,
                        outerRadius: 178,
                        startAngle: angleRange.lowerBound,
                        endAngle: angleRange.upperBound
                    )
                    .stroke(
                        Color.gray00.opacity(isFocused ? 0.42 : 0.28),
                        lineWidth: 0.75
                    )
                }
                .contentShape(
                    FanSector(
                        innerRadius: 34,
                        outerRadius: 178,
                        startAngle: angleRange.lowerBound,
                        endAngle: angleRange.upperBound
                    )
                )
                .onTapGesture { onSelect(index) }
                .allowsHitTesting(model.mode == .sticky)
                .scaleEffect(isFocused ? 1.025 : 1, anchor: .bottom)
                .animation(.spring(response: 0.2, dampingFraction: 0.88), value: isFocused)
            }
        }
        .frame(width: 356, height: 356)
        .opacity(model.mode == .dragging ? 1 : 0.78)
        .transition(.scale(scale: 0.82, anchor: .bottom).combined(with: .opacity))
    }

    private func targetBubble(_ contact: FamilyContact, index: Int) -> some View {
        let isFocused = model.focusedIndex == index

        return VStack(spacing: Spacing.x1) {
            Circle()
                .fill(LinearGradient.avatar)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(Color.greenNormal.opacity(0.55), lineWidth: isFocused ? 1.5 : 0)
                )
                .shadow(color: .black.opacity(isFocused ? 0.12 : 0.07), radius: isFocused ? 12 : 8, y: 4)
                .scaleEffect(isFocused ? 1.06 : 1)

            Text(contact.name)
                .caption_01_semibold(isFocused ? .gray900 : .gray800)
        }
        .offset(model.offset(for: index))
        .animation(.spring(response: 0.2, dampingFraction: 0.88), value: isFocused)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8)
                .delay(model.isPresented ? Double(index) * 0.04 : 0),
            value: model.isPresented
        )
        .contentShape(Circle())
        .onTapGesture { onSelect(index) }
        .allowsHitTesting(model.mode == .sticky)
    }
}

private struct FanSector: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 32
        var path = Path()

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            let point = point(center: center, radius: outerRadius, angle: angle)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        for step in (0...steps).reversed() {
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            path.addLine(to: point(center: center, radius: innerRadius, angle: angle))
        }

        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
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
