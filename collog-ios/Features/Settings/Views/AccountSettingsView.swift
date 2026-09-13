//
//  AccountSettingsView.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/19/26.
//

import SwiftUI
import AuthenticationServices

struct AccountSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(CallCenter.self) private var callCenter
    @State private var selectedRole: UserRoleOption = .child
    @State private var isSubmitting = false
    @State private var confirmsRoleChange = false
    @State private var confirmsDeletion = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.x5) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(displayName)
                        .subtitle_01(.gray900)

                    Text(roleText)
                        .body_03_medium(.gray700)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()

                SettingsSection(title: "기본 정보") {
                    SettingsValueRow(label: "이름", value: displayName)
                    DividerLine()
                    if let phone = environment.session.user?.phone {
                        SettingsValueRow(label: "전화번호", value: phone)
                        DividerLine()
                    }
                    SettingsValueRow(label: "역할", value: roleText)
                }

                SettingsSection(title: "가족") {
                    SettingsValueRow(label: "등록된 가족", value: "\(environment.family.contacts.count)명")
                }

                if environment.session.isAuthenticated {
                    SettingsSection(title: "역할 변경") {
                        VStack(alignment: .leading, spacing: Spacing.x3) {
                            Picker("역할", selection: $selectedRole) {
                                ForEach(UserRoleOption.allCases) { role in
                                    Text(role.title).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("부모는 본인의 건강 기록을, 자녀는 가족의 건강 기록을 확인해요.")
                                .caption_01_medium(.gray700)
                            Button("역할 저장") { confirmsRoleChange = true }
                                .disabled(selectedRole.rawValue == environment.session.user?.role)
                        }
                        .padding(Spacing.x4)
                    }
                    .disabled(isSubmitting || callCenter.hasCallInProgress)

                    if callCenter.hasCallInProgress {
                        Text("통화를 마친 뒤 역할 변경과 계정 삭제를 할 수 있어요.")
                            .caption_01_medium(.gray700)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .caption_01_medium(.red500)
                    }
                    if isSubmitting { ProgressView() }

                    Button("계정 삭제", role: .destructive) { confirmsDeletion = true }
                        .disabled(isSubmitting || callCenter.hasCallInProgress)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x4)
        }
        .background(Color.gray50)
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeDetailHeader(title: "계정 정보")
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedRole = UserRoleOption(rawValue: environment.session.user?.role ?? "") ?? .child
        }
        .alert("역할을 \(selectedRole.title)(으)로 변경할까요?", isPresented: $confirmsRoleChange) {
            Button("취소", role: .cancel) {}
            Button("변경") { Task { await updateRole() } }
        } message: {
            Text("가족은 유지돼요. 부모로 변경하면 건강 정보 동의와 프로필 설정이 필요할 수 있어요.")
        }
        .alert("계정을 삭제할까요?", isPresented: $confirmsDeletion) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("계정과 관련 통화 기록, 녹음, 건강 정보가 삭제돼요. 삭제 후에는 복구할 수 없어요.")
        }
    }

    private func updateRole() async {
        guard !isSubmitting, !callCenter.hasCallInProgress else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let user = try await environment.api.updateRole(selectedRole)
            try environment.session.updateUser(user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        guard !isSubmitting, !callCenter.hasCallInProgress else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let userId = environment.session.user?.id
        do {
            var authorization: AppleDeletionBody?
            if let appleUserId = environment.session.user?.appleUserId {
                let challenge = try await environment.api.appleLoginChallenge()
                let authorizer = AppleDeletionAuthorization()
                authorization = try await authorizer.authorize(challenge: challenge, user: appleUserId)
            }
            guard environment.session.user?.id == userId else { return }
            try await environment.api.deleteAccount(authorization: authorization)
            if environment.session.user?.id == userId {
                environment.session.signOut()
                environment.settings.isGuestMode = false
            }
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var displayName: String {
        environment.session.user?.name ?? "데모 사용자"
    }

    private var roleText: String {
        environment.session.user?.role == UserRoleOption.parent.rawValue ? "부모" : "자녀"
    }
}

struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.x3) {
            Text(label)
                .body_02_medium(.gray800)

            Spacer(minLength: Spacing.x3)

            Text(value)
                .body_02_medium(.gray900)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.x4)
        .frame(minHeight: 52)
    }
}

#Preview {
    let environment = AppEnvironment()
    NavigationStack {
        AccountSettingsView()
            .environment(environment)
            .environment(CallCenter(environment: environment))
    }
}
