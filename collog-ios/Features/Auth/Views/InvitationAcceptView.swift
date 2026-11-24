//
//  InvitationAcceptView.swift
//  collog-ios
//
//  Created by dohyeoplim on 9/12/26.
//

import SwiftUI

struct InvitationAcceptView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onAccepted: () -> Void
    var showsAccountActions = true
    var onSkip: (() -> Void)?

    /// 받은 코드로 들어가면 서버가 혼자뿐인 내 가족을 정리해, 수락되지 않은 내 초대(만료 포함)도 함께 사라진다.
    static let sentInvitationNote = "초대 코드를 입력하면 내가 보낸 초대는 취소돼요."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x6) {
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text("가족 초대 코드를 입력해주세요")
                        .headline_02(.gray900)
                    Text("가족에게 받은 코드로 가족에 참여할 수 있어요")
                        .body_02_medium(.gray800)
                }

                TextField("초대 코드", text: $code)
                    .pretendardStyle(.medium, 16)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, Spacing.x4)
                    .frame(height: 52)
                    .background(Color.gray00, in: RoundedRectangle(cornerRadius: Radius.btnSmall))

                if environment.family.connectGuide(using: environment)?.hasSentInvitation == true {
                    Text(Self.sentInvitationNote)
                        .caption_01_medium(.gray700)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .caption_01_medium(.red500)
                }

                Button {
                    Task { await accept() }
                } label: {
                    Text(isSubmitting ? "확인 중" : "가족 참여하기")
                        .body_01_semibold(.gray00)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.greenNormal, in: RoundedRectangle(cornerRadius: Radius.btnSmall))
                }
                .buttonStyle(.plain)
                .disabled(code.count != 6 || !code.allSatisfy(\.isNumber) || isSubmitting)

                if let onSkip {
                    VStack(spacing: Spacing.x2) {
                        Button(action: onSkip) {
                            Text("나중에 입력하기")
                                .body_02_semibold(.greenDark)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)

                        Text("초대 코드가 없으면 건너뛰세요. 설정에서도 입력할 수 있어요.")
                            .caption_01_medium(.gray700)
                    }
                    .frame(maxWidth: .infinity)
                }

                if showsAccountActions {
                    OnboardingAccountActions()
                        .disabled(isSubmitting)
                }
            }
            .padding(.horizontal, Spacing.x5)
            .padding(.vertical, Spacing.x8)
        }
        .background(Color.gray50.ignoresSafeArea())
        // 어느 길로 열어도 내가 보낸 초대가 있는지 지금 상태로 본다(로그인 직후에는 아직 읽은 적이 없다).
        // 화면을 닫아도 끝까지 읽는다: 도중에 취소되면 가족 목록에 취소 오류가 남는다.
        .onAppear {
            Task { await environment.family.refresh(using: environment) }
        }
    }

    private func accept() async {
        isSubmitting = true
        errorMessage = nil
        let userId = environment.session.user?.id
        defer { isSubmitting = false }
        do {
            let accepted = try await environment.api.acceptInvitation(
                code: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard environment.session.user?.id == userId else { return }
            try environment.session.joinFamily(accepted.familyId)
            await environment.family.refresh(using: environment)
            onAccepted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct InvitationAcceptSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAccepted: () -> Void = {}

    var body: some View {
        NavigationStack {
            InvitationAcceptView(onAccepted: {
                dismiss()
                onAccepted()
            }, showsAccountActions: false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
