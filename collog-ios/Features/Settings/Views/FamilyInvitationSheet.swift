//
//  FamilyInvitationSheet.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import SwiftUI

struct FamilyInvitationSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relation = "MOTHER"
    @State private var invitationCode: String?
    @State private var shareText: String?
    @State private var isSubmitting = false
    @State private var errorText: String?

    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x5) {
                    Text("초대할 가족")
                        .headline_02(.gray900)

                    if let invitationCode, let shareText {
                        invitationResult(code: invitationCode, shareText: shareText)
                    } else {
                        invitationForm
                    }

                    if let errorText {
                        Text(errorText)
                            .body_03_medium(.red500)
                    }
                }
                .padding(.horizontal, Spacing.x5)
                .padding(.vertical, Spacing.x5)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.gray50)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("완료")
                            .body_02_semibold(.greenDark)
                    }
                }
            }
        }
    }

    private var invitationForm: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            TextField("이름", text: $name)
                .pretendardStyle(.medium, 16)
                .padding(.horizontal, Spacing.x4)
                .frame(height: 52)
                .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))

            Picker("관계", selection: $relation) {
                Text("어머니").tag("MOTHER")
                Text("아버지").tag("FATHER")
            }
            .pickerStyle(.segmented)

            Button {
                Task { await createInvitation() }
            } label: {
                Text(isSubmitting ? "만드는 중" : "초대 만들기")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        name.isEmpty || isSubmitting ? Color.gray500 : Color.greenNormal,
                        in: RoundedRectangle(cornerRadius: Radius.btnSmall)
                    )
            }
            .buttonStyle(.plain)
            .disabled(name.isEmpty || isSubmitting)
        }
    }

    private func invitationResult(code: String, shareText: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("초대 코드")
                .body_03_medium(.gray700)

            Text(code)
                .pretendard(.semiBold, 28, .gray900)
                .textSelection(.enabled)

            ShareLink(item: shareText) {
                Text("초대 내용 공유")
                    .body_01_semibold(.gray00)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
            }
        }
        .cardSurface()
    }

    private func createInvitation() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }

        guard !environment.settings.isGuestMode, environment.session.user?.role == "CHILD" else { return }

        guard let familyId = environment.session.familyId else { return }
        do {
            let invitation = try await environment.api.createInvitation(
                familyId: familyId,
                name: name,
                relation: relation
            )
            invitationCode = invitation.code
            shareText = invitation.shareText
            onCreated()
            Haptics.commit()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
