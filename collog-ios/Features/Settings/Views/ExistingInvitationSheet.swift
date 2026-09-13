//
//  ExistingInvitationSheet.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/13/26.
//

import SwiftUI

struct ExistingInvitationSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var invitation: FamilyInvitation
    @State private var replacement: InvitationDTO?
    @State private var isSubmitting = false
    @State private var errorText: String?
    let onUpdated: () -> Void

    init(invitation: FamilyInvitation, onUpdated: @escaping () -> Void) {
        _invitation = State(initialValue: invitation)
        self.onUpdated = onUpdated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("가족 초대").headline_02(.gray900)
            if replacement != nil || !invitation.isExpired {
                Text(replacement?.code ?? invitation.code)
                    .pretendard(.semiBold, 28, .gray900)
                    .textSelection(.enabled)
                ShareLink("초대 내용 공유", item: replacement?.shareText ?? invitation.shareText)
            } else {
                Text("초대가 만료됐어요. 새 코드를 만들어 주세요.").body_03_medium(.gray700)
            }
            Button(isSubmitting ? "만드는 중" : "새 초대 코드 만들기") {
                Task { await resend() }
            }
            .disabled(isSubmitting)
            if let errorText { Text(errorText).body_03_medium(.red500) }
        }
        .padding(Spacing.x5)
    }

    private func resend() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            replacement = try await environment.api.resendInvitation(
                invitationId: replacement?.invitationId ?? invitation.invitationId
            )
            onUpdated()
        } catch {
            errorText = error.localizedDescription
            onUpdated()
        }
    }
}
