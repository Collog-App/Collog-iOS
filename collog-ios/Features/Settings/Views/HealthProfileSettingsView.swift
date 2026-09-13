//
//  HealthProfileSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI

struct HealthProfileSettingsView: View {
    private struct ProfileTarget: Identifiable {
        let id: String
        let name: String
    }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @AppStorage("settings.guestHealthConditions") private var guestConditions = "HYPERTENSION"
    @State private var selected: Set<HealthCondition> = []
    @State private var hasNoConditions = false
    @State private var targets: [ProfileTarget] = []
    @State private var target: ProfileTarget?
    @State private var profileLoaded = false
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

                if !environment.settings.isGuestMode {
                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        Text("건강 프로필을 수정할 사람")
                            .body_02_medium(.gray900)
                        ForEach(targets) { candidate in
                            Button {
                                Task { await loadProfile(for: candidate) }
                            } label: {
                                HStack {
                                    Text(candidate.name)
                                    Spacer()
                                    if target?.id == candidate.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(Spacing.x4)
                                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading || isSaving)
                            .accessibilityAddTraits(target?.id == candidate.id ? .isSelected : [])
                        }
                        if let target {
                            Text("\(target.name)님의 건강 정보를 수정해요.")
                                .body_03_medium(.gray700)
                        } else if !targets.isEmpty {
                            Text("이름을 선택한 뒤 건강 정보를 입력해주세요.")
                                .body_03_medium(.gray700)
                        }
                    }
                }

                VStack(spacing: Spacing.x2) {
                    ForEach(HealthCondition.allCases) { condition in
                        conditionRow(condition)
                    }
                    conditionRow(nil)
                }
                .disabled(!profileLoaded || isLoading || isSaving)

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
                            canSave ? Color.greenNormal : Color.gray500,
                            in: RoundedRectangle(cornerRadius: Radius.btnSmall, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "건강 프로필")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private var canSave: Bool {
        profileLoaded && (!selected.isEmpty || hasNoConditions) && !isSaving && !isLoading
    }

    private func conditionRow(_ condition: HealthCondition?) -> some View {
        let isSelected = condition.map { selected.contains($0) } ?? hasNoConditions

        return Button {
            errorText = nil
            if let condition {
                hasNoConditions = false
                if isSelected {
                    selected.remove(condition)
                } else {
                    selected.insert(condition)
                }
            } else {
                selected.removeAll()
                hasNoConditions.toggle()
            }
            Haptics.focus()
        } label: {
            HStack(spacing: Spacing.x3) {
                Text(condition?.title ?? "해당 없음")
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func load() async {
        defer { isLoading = false }
        if environment.settings.isGuestMode {
            let values = guestConditions.split(separator: ",").map(String.init)
            selected = Set(values.compactMap(HealthCondition.init(rawValue:)))
            hasNoConditions = selected.isEmpty
            profileLoaded = true
            return
        }

        guard let user = environment.session.user else {
            errorText = "로그인이 필요해요."
            return
        }
        if user.role == "PARENT" {
            let ownProfile = ProfileTarget(id: user.id, name: user.name)
            targets = [ownProfile]
            await loadProfile(for: ownProfile)
            return
        }
        guard let familyId = environment.session.familyId else {
            errorText = "가족을 먼저 초대해주세요."
            return
        }
        do {
            let members = try await environment.api.members(familyId: familyId)
            targets = members.compactMap { member in
                guard member.role == "PARENT", let id = member.userId else { return nil }
                return ProfileTarget(id: id, name: member.name)
            }
            if targets.isEmpty { errorText = "등록된 부모님이 없어요. 가족 초대를 먼저 완료해주세요." }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadProfile(for candidate: ProfileTarget) async {
        isLoading = true
        profileLoaded = false
        errorText = nil
        target = candidate
        selected.removeAll()
        hasNoConditions = false
        defer { isLoading = false }
        do {
            let profile = try await environment.api.profile(parentId: candidate.id)
            selected = Set(profile.conditions.compactMap(HealthCondition.init(rawValue:)))
            hasNoConditions = profile.hasCompletedSetup && selected.isEmpty
            profileLoaded = true
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func save() async {
        guard canSave else { return }
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

        guard let parentId = target?.id else {
            errorText = "건강 프로필을 수정할 사람을 선택해주세요."
            return
        }
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
