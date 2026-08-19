//
//  HealthProfileSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HealthProfileSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @AppStorage("settings.guestHealthConditions") private var guestConditions = "HYPERTENSION"
    @State private var selected: Set<HealthCondition> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x5) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("건강 질문을 맞춤 준비해드려요")
                        .subtitle_01(.gray900)

                    Text("선택한 항목은 오늘의 질문과 통화 요약을 준비할 때 참고해요.")
                        .body_03_medium(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardSurface()

                VStack(spacing: Spacing.x2) {
                    ForEach(HealthCondition.allCases) { condition in
                        conditionRow(condition)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .body_03_medium(.red500)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "저장 중" : "저장")
                        .body_01_semibold(.gray00)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            selected.isEmpty || isSaving ? Color.gray500 : Color.greenNormal,
                            in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty || isSaving || isLoading)
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "나의 건강 프로필")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func conditionRow(_ condition: HealthCondition) -> some View {
        let isSelected = selected.contains(condition)

        return Button {
            errorText = nil
            if isSelected {
                selected.remove(condition)
            } else {
                selected.insert(condition)
            }
            Haptics.focus()
        } label: {
            HStack(spacing: Spacing.x3) {
                Text(condition.title)
                    .body_02_medium(.gray900)

                Spacer(minLength: Spacing.x3)

                if isSelected {
                    Icon(name: "checkmark", size: 16, weight: .semibold, color: .greenDark)
                }
            }
            .padding(.horizontal, Spacing.x4)
            .frame(height: 54)
            .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(isSelected ? Color.green300 : Color.gray200, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        defer { isLoading = false }
        if environment.settings.isGuestMode {
            let values = guestConditions.split(separator: ",").map(String.init)
            selected = Set(values.compactMap(HealthCondition.init(rawValue:)))
            return
        }

        guard let parentId = await environment.subjectParentId() else { return }
        do {
            let profile = try await environment.api.profile(parentId: parentId)
            selected = Set(profile.conditions.compactMap(HealthCondition.init(rawValue:)))
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorText = nil
        defer { isSaving = false }

        let values = selected.map(\.rawValue).sorted()
        if environment.settings.isGuestMode {
            guestConditions = values.joined(separator: ",")
            Haptics.commit()
            dismiss()
            return
        }

        guard let parentId = await environment.subjectParentId() else { return }
        do {
            _ = try await environment.api.updateProfile(parentId: parentId, conditions: values)
            Haptics.commit()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        HealthProfileSettingsView()
            .environment(AppEnvironment())
    }
}
