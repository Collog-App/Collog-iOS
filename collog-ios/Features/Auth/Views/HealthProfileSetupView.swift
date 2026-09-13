//
//  HealthProfileSetupView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import SwiftUI

struct HealthProfileSetupView: View {
    @Environment(AppEnvironment.self) private var environment

    var onCompleted: () -> Void

    @State private var selected: Set<HealthCondition> = []
    @State private var hasNoConditions = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x6) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("관리 중인 질환을 알려주세요")
                    .headline_02(.gray900)
                Text("등록한 질환에 맞춰 오늘의 질문을 준비해드려요. 나중에 설정에서 바꿀 수 있어요.")
                    .body_02_medium(.gray800)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Spacing.x2) {
                ForEach(HealthCondition.allCases) { condition in
                    row(for: condition)
                }
                row(for: nil)
            }

            if let errorMessage {
                Text(errorMessage)
                    .caption_01_medium(.red500)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: submit) {
                Text("완료")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        !canSubmit ? Color.gray500 : Color.greenNormal,
                        in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            OnboardingAccountActions()
                .disabled(isSubmitting)
        }
        .padding(.horizontal, Spacing.x5)
        .padding(.top, Spacing.x8)
        .padding(.bottom, Spacing.x8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.gray50)
    }

    private var canSubmit: Bool { (!selected.isEmpty || hasNoConditions) && !isSubmitting }

    private func row(for condition: HealthCondition?) -> some View {
        let isSelected = condition.map { selected.contains($0) } ?? hasNoConditions
        return Button {
            if let condition {
                hasNoConditions = false
                if selected.contains(condition) {
                    selected.remove(condition)
                } else {
                    selected.insert(condition)
                }
            } else {
                selected.removeAll()
                hasNoConditions.toggle()
            }
        } label: {
            HStack(spacing: Spacing.x2) {
                Text(condition?.title ?? "해당 없음")
                    .body_02_medium(isSelected ? .gray900 : .gray800)

                Spacer(minLength: Spacing.x2)

                Circle()
                    .fill(isSelected ? Color.greenNormal : Color.gray300)
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, Spacing.x4)
            .frame(height: 56)
            .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                    .stroke(isSelected ? Color.greenNormal : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func submit() {
        guard canSubmit, let parentId = environment.session.user?.id else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await environment.api.updateProfile(
                    parentId: parentId,
                    conditions: selected.map(\.rawValue)
                )
                onCompleted()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    HealthProfileSetupView {}
        .environment(AppEnvironment())
}
