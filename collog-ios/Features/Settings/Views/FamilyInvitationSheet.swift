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
    @State private var createdFamilyId: String?

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
            .onDisappear(perform: joinCreatedFamily)
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

            // 관계 일곱 가지는 분할 선택에 넣으면 글자가 잘려 메뉴로 고른다
            HStack {
                Text("관계")
                    .body_02_medium(.gray900)

                Spacer(minLength: Spacing.x3)

                Picker("관계", selection: $relation) {
                    ForEach(FamilyRelation.invitationOptions, id: \.self) { option in
                        Text(FamilyRelation.title(option) ?? "").tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.greenDark)
            }
            .padding(.horizontal, Spacing.x4)
            .frame(height: 52)
            .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))

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

        guard !environment.settings.isGuestMode else { return }

        do {
            let hadFamily = environment.session.familyId != nil
            let familyId = if let familyId = environment.session.familyId {
                familyId
            } else {
                try await environment.api.createFamily()
            }
            let invitation = try await environment.api.createInvitation(
                familyId: familyId,
                name: name,
                relation: relation
            )
            invitationCode = invitation.code
            shareText = invitation.shareText
            if hadFamily { onCreated() } else { createdFamilyId = familyId }
            Haptics.commit()
        } catch {
            errorText = error.localizedDescription
        }
    }

    // 새로 만든 가족은 시트가 닫힐 때 세션에 넣는다. 넣는 순간 앱이 홈으로 돌아가 코드를 보여 줄 수 없다.
    private func joinCreatedFamily() {
        guard let createdFamilyId, environment.session.familyId == nil else { return }
        try? environment.session.joinFamily(createdFamilyId)
        onCreated()
    }
}
